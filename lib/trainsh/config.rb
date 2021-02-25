require 'mixlib/config'

module TrainSH
  module Config
    extend Mixlib::Config
    config_strict_mode true

    default :log_level, :info

    default :pager, ENV['PAGER'] || 'less'
    default :editor, ENV['EDITOR'] || ENV['VISUAL'] || 'vi'

    default :user_config, "~/#{ENV['USER_CONF_DIR']}"
  end
end
