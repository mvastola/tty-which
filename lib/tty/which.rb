# frozen_string_literal: true

require_relative "which/version"

module TTY
  # A class responsible for finding an executable in the PATH
  module Which
    # Find an executable in a platform independent way
    #
    # @param [String] cmd
    #   the command to search for
    # @param [Array<String>] paths
    #   the paths to look through
    # @param [Boolean] all
    #   whether to return all matching paths
    #
    # @example
    #   which("ruby")                 # => "/usr/local/bin/ruby"
    #   which("/usr/local/bin/ruby")  # => "/usr/local/bin/ruby"
    #   which("foo")                  # => nil
    #   which("ruby", all: true)      # => ["/usr/local/bin/ruby", "/usr/bin/ruby", ...]
    #   which("foo", all: true)       # => []
    #
    # @example
    #   which("ruby", paths: ["/usr/locale/bin", "/usr/bin", "/bin"])
    #
    # @return [String, Array<String>, nil]
    #   the first absolute path to an executable if found, `nil` or empty array otherwise
    def which(cmd, paths: search_paths, all: false)
      enumerator = each_path(cmd, paths:)
      all ? enumerator.to_a : enumerator.first
    end
    module_function :which

    # @api public
    # Iterate through paths for an executable in a platform independent way
    #
    # @param [String] cmd
    #   the command to search for
    # @param [optional, Array<String>] paths
    #   the paths to look through
    # @yieldparam [optional, String] an absolute path to the executable
    #
    # @example
    #   which("ruby")                 # => enumerator of "/usr/local/bin/ruby", "/usr/bin/ruby", ...
    #   which("/usr/local/bin/ruby")  # => enumerator of "/usr/local/bin/ruby"
    #   which("foo")                  # => empty enumerator
    #
    # @example
    #   which("ruby", paths: ["/usr/locale/bin", "/usr/bin", "/bin"])
    #
    # @return [Enumerator<String>, nil]
    #   if no block is given, a (lazy) enumerator of all absolute paths to the executable
    #
    # @api public
    def each_path(cmd, paths: search_paths, &block)
      unless block_given?
        return Enumerator::Lazy.new(self) do |yielder|
          each_path(cmd, paths:, &yielder.to_proc)
        end
      end

      if file_with_path?(cmd)
        yield cmd if executable_file?(cmd)

        extensions.each do |ext|
          exe = "#{cmd}#{ext}"
          yield ::File.absolute_path(exe) if executable_file?(exe)
        end
        return nil
      end

      paths.each do |path|
        if file_with_exec_ext?(cmd)
          exe = ::File.join(path, cmd)
          yield ::File.absolute_path(exe) if executable_file?(exe)
        end
        extensions.each do |ext|
          exe = ::File.join(path, "#{cmd}#{ext}")
          yield ::File.absolute_path(exe) if executable_file?(exe)
        end
      end
      nil
    end
    module_function :each_path

    # Check if executable exists in the path
    #
    # @param [String] cmd
    #   the executable to check
    #
    # @param [Array<String>] paths
    #   paths to check
    #
    # @return [Boolean]
    #
    # @api public
    def exist?(cmd, paths: search_paths)
      !which(cmd, paths: paths).nil?
    end
    module_function :exist?

    # Find default system paths
    #
    # @param [String] path
    #   the path to search through
    #
    # @example
    #   search_paths("/usr/local/bin:/bin")
    #   # => ["/bin"]
    #
    # @return [Array<String>]
    #   the array of paths to search
    #
    # @api private
    def search_paths(path = ENV["PATH"])
      paths = if path && !path.empty?
                path.split(::File::PATH_SEPARATOR)
              else
                %w[/usr/local/bin /usr/ucb /usr/bin /bin]
              end
      paths.select(&Dir.method(:exist?))
    end
    module_function :search_paths

    # All possible file extensions
    #
    # @example
    #   extensions(".exe;cmd;.bat")
    #   # => [".exe", ".bat"]
    #
    # @param [String] path_ext
    #   a string of semicolon separated filename extensions
    #
    # @return [Array<String>]
    #   an array with valid file extensions
    #
    # @api private
    def extensions(path_ext = ENV["PATHEXT"])
      return [""] unless path_ext

      path_ext.split(::File::PATH_SEPARATOR).select { |part| part.include?(".") }
    end
    module_function :extensions

    # Determines if filename is an executable file
    #
    # @example Basic usage
    #   executable_file?("/usr/bin/less") # => true
    #
    # @example Executable in directory
    #   executable_file?("less", "/usr/bin") # => true
    #   executable_file?("less", "/usr") # => false
    #
    # @param [String] filename
    #   the path to file
    # @param [String] dir
    #   the directory within which to search for filename
    #
    # @return [Boolean]
    #
    # @api private
    def executable_file?(filename, dir = nil)
      path = ::File.join(dir, filename) if dir
      path ||= filename
      ::File.file?(path) && ::File.executable?(path)
    end
    module_function :executable_file?

    # Check if command itself has executable extension
    #
    # @param [String] filename
    #   the path to executable file
    #
    # @example
    #   file_with_exec_ext?("file.bat")
    #   # => true
    #
    # @return [Boolean]
    #
    # @api private
    def file_with_exec_ext?(filename)
      extension = ::File.extname(filename)
      return false if extension.empty?

      extensions.any? { |ext| extension.casecmp(ext).zero? }
    end
    module_function :file_with_exec_ext?

    # Check if executable file is part of absolute/relative path
    #
    # @param [String] cmd
    #   the executable to check
    #
    # @return [Boolean]
    #
    # @api private
    def file_with_path?(cmd)
      ::File.expand_path(cmd) == cmd
    end
    module_function :file_with_path?
  end # Which
end # TTY
