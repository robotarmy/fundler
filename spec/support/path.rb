module Spec
  module Path
    def root
      @root ||= Pathname.new(File.expand_path("../../..", __FILE__))
    end

    def tmp(*path)
      root.join("tmp", *path)
    end

    def home(*path)
      tmp.join("home", *path)
    end

    def default_fundle_path(*path)
      system_gem_path(*path)
    end

    def fundled_app(*path)
      root = tmp.join("fundled_app")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    alias fundled_app1 fundled_app

    def fundled_app2(*path)
      root = tmp.join("fundled_app2")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    def vendored_gems(path = nil)
      fundled_app("vendor/fundle/#{Gem.ruby_engine}/#{Gem::ConfigMap[:ruby_version]}/#{path}")
    end

    def cached_gem(path)
      fundled_app("vendor/cache/#{path}.gem")
    end

    def base_system_gems
      tmp.join("gems/base")
    end

    def gem_repo1(*args)
      tmp("gems/remote1", *args)
    end

    def gem_repo2(*args)
      tmp("gems/remote2", *args)
    end

    def gem_repo3(*args)
      tmp("gems/remote3", *args)
    end

    def system_gem_path(*path)
      tmp("gems/system", *path)
    end

    def lib_path(*args)
      tmp("libs", *args)
    end

    def fundler_path
      Pathname.new(File.expand_path('../../../lib', __FILE__))
    end

    extend self
  end
end
