class WidgetTestsController < ActionController::Base
  before_action :ensure_page_enabled
  before_action :ensure_web_widget
  before_action :ensure_widget_position
  before_action :ensure_widget_type
  before_action :ensure_widget_style
  before_action :ensure_dark_mode

  def index
    render
  end

  private

  # Off by default in every environment. ENABLE_WIDGET_TEST_PAGE=true turns it on.
  def ensure_page_enabled
    head :not_found unless ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_WIDGET_TEST_PAGE', false))
  end

  def ensure_widget_style
    @widget_style = params[:widget_style] || 'standard'
  end

  def ensure_dark_mode
    @dark_mode = params[:dark_mode] || 'light'
  end

  def ensure_widget_position
    @widget_position = params[:position] || 'left'
  end

  def ensure_widget_type
    @widget_type = params[:type] || 'expanded_bubble'
  end

  def inbox_id
    @inbox_id ||= params[:inbox_id] || Channel::WebWidget.first.inbox.id
  end

  def ensure_web_widget
    @inbox = Inbox.find(inbox_id)
    @web_widget = @inbox.channel
  end
end
