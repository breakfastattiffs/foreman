class HostBuildStatus
  attr_reader :host, :state, :errors
  delegate :available_template_kinds, :smart_proxies, :to => :host
  VALIDATION_TYPES = [:host, :templates, :proxies]

  def initialize(host)
    @host   = host
    @errors = {}
    @state  = true # default to true state
    VALIDATION_TYPES.each {|type| @errors[type] = []}
  end

  def check_all_statuses
    host_status
    templates_status
    smart_proxies_status
  end

  private

  def host_status
    return if host.valid?
    host.errors.full_messages.each do |error|
      fail!(:host, error.to_s, host.to_label)
    end
  rescue => error
    fail!(:host, _('Failed to validate %s: %s') % [host, error.to_s], host.to_label)
  end

  def templates_status
    fail!(:templates, _('No templates found for this host.')) if available_template_kinds.empty?

    available_template_kinds.each do |template|
      begin
        valid_template = host.render_template(template.template)
        fail!(:templates, _('Template %s is empty.') % template.name, template.name) if valid_template.blank?
      rescue => exception
        fail!(:templates, (_('Failure parsing %s: %s.') % [template.name, exception]), template.name)
      end
    end
  end

  def smart_proxies_status
    fail!(:proxies, _('No smart proxies found.')) if smart_proxies.empty?

    smart_proxies.each do |proxy|
      begin
        errors = proxy.refresh.messages.any?
        errors = errors.is_a?(Array) ? errors.to_sentence : errors
        fail!(:proxies, _('Failure deploying via smart proxy %s: %s.') % [proxy, errors], proxy.id) if errors
      rescue => error
        fail!(:proxies, _('Error connecting to %s: %s.') % [proxy, error], proxy.id)
      end
    end
  end

  def fail!(type, message, id = nil)
    @state = false
    @errors[type] << {:message => message, :edit_id => id}
  end
end
