# Turns an Insights result into a CSV, Excel or PDF file. Used for downloads now and scheduled emails later,
# so a report reads the same wherever it ends up.
# CSV and Excel keep numbers as numbers (times in minutes) so they can be sorted and summed; the PDF shows them for reading.
class Insights::ExportService
  CONTENT_TYPES = {
    'csv' => 'text/csv',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pdf' => 'application/pdf'
  }.freeze
  FORMATS = CONTENT_TYPES.keys.freeze
  TIME_METRICS = %w[first_response_time median_first_response_time resolution_time median_resolution_time].freeze
  DATE_FORMAT = '%-d %b %Y'.freeze

  # result: what QueryService returned, or a snapshot's stored copy of it
  def initialize(title:, config:, result:)
    @title = title
    @config = config
    @result = result.deep_stringify_keys
  end

  def render(format)
    public_send(:"to_#{format}")
  end

  def filename(format)
    "#{@title.parameterize.presence || 'insights'}-#{Time.zone.at(@config.until).in_time_zone(@config.timezone).to_date.iso8601}.#{format}"
  end

  def to_csv
    CSV.generate { |csv| [headers, *rows(:raw), totals(:raw)].each { |row| csv << row } }
  end

  def to_xlsx
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: 'Report') do |sheet|
      bold = sheet.styles.add_style(b: true)
      sheet.add_row [@title], style: bold
      period_lines.each { |line| sheet.add_row [line] }
      sheet.add_row []
      sheet.add_row headers, style: bold
      rows(:raw).each { |row| sheet.add_row row }
      sheet.add_row totals(:raw), style: bold
    end
    package.to_stream.read
  end

  def to_pdf
    pdf = Prawn::Document.new(page_size: 'A4', page_layout: :landscape, margin: 36)
    pdf.text pdf_text(@title), size: 16, style: :bold
    period_lines.each { |line| pdf.text pdf_text(line), size: 9, color: '555555' }
    pdf.move_down 12
    pdf_table(pdf)
    pdf.render
  end

  # The totals, ready to read in an email
  def summary
    @config.metrics.map do |metric|
      current = @result.dig('totals', metric)
      line = { 'label' => I18n.t("insights.metrics.#{metric}"), 'value' => format_value(metric, current, :display).to_s }
      compare? ? line.merge('versus' => versus(metric, current, @result.dig('previous_totals', metric))) : line
    end
  end

  def compare?
    @result['previous_totals'].present?
  end

  def period_lines
    lines = [I18n.t('insights.period', from: date(@config.since), to: date(@config.until))]
    lines << I18n.t('insights.compared_with', from: date(@config.compare_since), to: date(@config.compare_until)) if compare?
    lines << I18n.t('insights.generated', time: Time.current.in_time_zone(@config.timezone).strftime("#{DATE_FORMAT} %H:%M"))
  end

  private

  # One column per metric, with the compared figure and change underneath, so the table fits the page
  def pdf_table(pdf)
    data = pdf_data
    figures = [@config.group_by.size, 1].max...data.first.size
    pdf.table(data, header: true, width: pdf.bounds.width, cell_style: { size: 8, padding: [4, 6], border_color: 'DDDDDD' }) do
      row(0).font_style = :bold
      row(0).background_color = 'F2F2F2'
      row(-1).font_style = :bold
      columns(figures).align = :right
    end
  end

  def pdf_data
    total_labels = totals(:display).first([@config.group_by.size, 1].max)
    rows = @result['rows'].map { |row| dimension_cells(row['dimensions']) + pdf_cells(row['metrics'], row['previous']) }
    [pdf_headers, *rows, total_labels + pdf_cells(@result['totals'], @result['previous_totals'])]
      .map { |row| row.map { |cell| pdf_text(cell.to_s) } }
  end

  def pdf_headers
    dimensions = @config.group_by.map { |dimension| I18n.t("insights.dimensions.#{dimension}") }
    (dimensions.presence || ['']) + @config.metrics.map { |metric| I18n.t("insights.metrics.#{metric}") }
  end

  def pdf_cells(current, previous)
    @config.metrics.map do |metric|
      value = format_value(metric, current&.dig(metric), :display).to_s
      compare? ? "#{value}\n#{versus(metric, current&.dig(metric), previous&.dig(metric))}" : value
    end
  end

  def versus(metric, current, previous)
    change = change(current, previous)
    text = I18n.t('insights.versus', value: format_value(metric, previous, :display))
    change ? "#{text} · #{format('%+g', change)}%" : text
  end

  def headers
    @config.group_by.map { |dimension| I18n.t("insights.dimensions.#{dimension}") } +
      @config.metrics.flat_map { |metric| metric_headers(metric) }
  end

  def metric_headers(metric)
    label = I18n.t("insights.metrics.#{metric}")
    label = "#{label} (#{I18n.t('insights.minutes')})" if TIME_METRICS.include?(metric)
    compare? ? [label, "#{label} #{I18n.t('insights.compared')}", "#{label} #{I18n.t('insights.change')}"] : [label]
  end

  def rows(style)
    @result['rows'].map do |row|
      dimension_cells(row['dimensions']) + metric_cells(row['metrics'], row['previous'], style)
    end
  end

  def totals(style)
    labels = @config.group_by.map.with_index { |_, index| index.zero? ? I18n.t('insights.total') : nil }
    labels = [I18n.t('insights.total')] if labels.empty?
    labels + metric_cells(@result['totals'], @result['previous_totals'], style)
  end

  def dimension_cells(dimensions)
    @config.group_by.map do |dimension|
      value = dimensions[dimension]
      next I18n.t('insights.none') if value.nil?
      next value if Insights::ReportConfig::TIME_DIMENSIONS.include?(dimension)

      @result.dig('labels', dimension, value.to_s) || "##{value}"
    end
  end

  def metric_cells(current, previous, style)
    @config.metrics.flat_map do |metric|
      cells = [format_value(metric, current&.dig(metric), style)]
      cells += [format_value(metric, previous&.dig(metric), style), change(current&.dig(metric), previous&.dig(metric))] if compare?
      cells
    end
  end

  def format_value(metric, value, style)
    return (style == :raw ? nil : '—') if value.nil?
    return (value / 60.0).round(1) if style == :raw && TIME_METRICS.include?(metric)
    return duration(value) if TIME_METRICS.include?(metric)

    value
  end

  def change(current, previous)
    return if current.nil? || previous.nil? || previous.zero?

    ((current - previous) * 100.0 / previous).round(1)
  end

  def duration(seconds)
    minutes = (seconds / 60.0).round
    return "#{seconds.round}s" if minutes.zero?

    minutes < 60 ? "#{minutes}m" : "#{minutes / 60}h #{format('%02d', minutes % 60)}m"
  end

  def date(timestamp)
    Time.zone.at(timestamp).in_time_zone(@config.timezone).strftime(DATE_FORMAT)
  end

  # Prawn's built-in fonts only cover Western European characters; anything else would stop the PDF, so it shows as "?"
  def pdf_text(text)
    text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').encode('UTF-8')
  end
end
