require 'rails_helper'

RSpec.describe Insights::ExportService do
  let(:config) do
    Insights::ReportConfig.new(metrics: %w[received first_response_time], group_by: %w[market], since: Time.find_zone('UTC').parse('2026-10-01').to_i,
                               until: Time.find_zone('UTC').parse('2026-10-31 23:59:59').to_i, compare: 'previous_period', timezone: 'UTC')
  end
  let(:result) do
    {
      rows: [
        { dimensions: { 'market' => 4 }, metrics: { 'received' => 12, 'first_response_time' => 150.0 },
          previous: { 'received' => 8, 'first_response_time' => 300.0 } },
        { dimensions: { 'market' => nil }, metrics: { 'received' => 1, 'first_response_time' => nil },
          previous: { 'received' => 0, 'first_response_time' => nil } }
      ],
      totals: { 'received' => 13, 'first_response_time' => 150.0 },
      previous_totals: { 'received' => 8, 'first_response_time' => 300.0 },
      labels: { 'market' => { '4' => 'Dar es Salaam ☕ Tanzania' } }
    }
  end
  let(:export) { described_class.new(title: 'Monthly by market', config: config, result: result) }

  it 'writes a CSV with names, times in minutes, compared figures and totals' do
    expect(CSV.parse(export.to_csv)).to eq([
                                             ['Market', 'Received', 'Received compared', 'Received change %',
                                              'Avg first response (minutes)', 'Avg first response (minutes) compared',
                                              'Avg first response (minutes) change %'],
                                             ['Dar es Salaam ☕ Tanzania', '12', '8', '50.0', '2.5', '5.0', '-50.0'],
                                             ['None', '1', '0', nil, nil, nil, nil],
                                             ['Total', '13', '8', '62.5', '2.5', '5.0', '-50.0']
                                           ])
  end

  it 'writes an Excel workbook with the title and period above the table' do
    sheet = nil
    Zip::File.open_buffer(StringIO.new(export.to_xlsx)) { |zip| sheet = zip.read('xl/worksheets/sheet1.xml').force_encoding('UTF-8') }

    expect(sheet).to include('Monthly by market', '1 Oct 2026 – 31 Oct 2026', 'Compared with 31 Aug 2026 – 30 Sep 2026', 'Dar es Salaam ☕ Tanzania')
  end

  it 'writes a PDF, even with names its font cannot draw' do
    expect(export.to_pdf).to start_with('%PDF')
  end

  it 'names the file after the report and its last day' do
    expect(export.filename('xlsx')).to eq('monthly-by-market-2026-10-31.xlsx')
  end
end
