module TrainSH
  PRODUCT = 'TrainSH'.freeze

  # The executable for interactive use
  EXEC = 'trainsh'.freeze

  # Prefix for environment variables
  ENV_PREFIX = 'TRAINSH_'.freeze

  # The user's configuration directory
  USER_CONF_DIR = '.trainsh'.freeze

  # Minimum version for remote file manipulation
  TRAIN_MUTABLE_VERSION = '3.5.0'.freeze

  # Prompt (TODO: Make configuratble)
  PROMPT = '%<exitcode_prefix>strainsh(@%<session_id>d %<backend>s://%<host>s)> '.freeze

  # Variable to remotely persist exit code
  EXITCODE_VAR = 'CMD_EXIT'.freeze
end
