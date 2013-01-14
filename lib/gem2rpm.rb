require 'erb'
require 'socket'
require 'gem2rpm/distro'
require 'gem2rpm/specification'

# Adapt to the differences between rubygems < 1.0.0 and after
# Once we can be reasonably certain that everybody has version >= 1.0.0
# all this logic should be killed
GEM_VERSION = Gem::Version.create(Gem::RubyGemsVersion)
HAS_REMOTE_INSTALLER = GEM_VERSION < Gem::Version.create("1.0.0")

HAS_GEMS_FORMAT= GEM_VERSION < Gem::Version.create("1.9")

if HAS_REMOTE_INSTALLER
  require 'rubygems/remote_installer'
end

if HAS_GEMS_FORMAT
  require 'rubygems/format'
else
  require 'rubygems/package'
end

module Gem2Rpm
  Gem2Rpm::VERSION = "0.7.1"

  if HAS_REMOTE_INSTALLER
    def self.find_download_url(name, version)
      installer = Gem::RemoteInstaller.new
      dummy, download_path = installer.find_gem_to_install(name, "=#{version}")
      download_path += "/gems/" if download_path.to_s != ""
      return download_path
    end
  else
    def self.find_download_url(name, version)
      dep = Gem::Dependency.new(name, "=#{version}")
      fetcher = Gem::SpecFetcher.fetcher
      dummy, download_path = fetcher.find_matching(dep, false, false).first
      download_path += "gems/" if download_path.to_s != ""
      return download_path
    end
  end

  if HAS_GEMS_FORMAT
    def self.get_spec(fname)
      format = Gem::Format.from_file_by_path(fname)
      return Gem2Rpm::Specification.new(format.spec)
    end
  else
    def self.get_spec(fname)
      return Gem::Package.new(fname).spec
    end
  end

  def Gem2Rpm.convert(fname, template=TEMPLATE, out=$stdout,
                      nongem=true, local=false, doc_subpackage = true)
    spec = get_spec(fname)
    spec.description ||= spec.summary
    download_path = ""
    unless local
      begin
        download_path = find_download_url(spec.name, spec.version)
      rescue Gem::Exception => e
        $stderr.puts "Warning: Could not retrieve full URL for #{spec.name}\nWarning: Edit the specfile and enter the full download URL as 'Source0' manually"
        $stderr.puts "#{e.inspect}"
      end
    end
    template = ERB.new(template, 0, '-')
    out.puts template.result(binding)
  rescue Gem::Exception => e
    puts e
  end

  # Returns the email address of the packager (i.e., the person running
  # gem2spec).  Taken from RPM macros if present, constructed from system
  # username and hostname otherwise.
  def Gem2Rpm.packager()
    packager = `rpmdev-packager`.chomp

    if packager.empty?
      packager = `rpm --eval '%{packager}'`.chomp
    end

    if packager.empty? or packager == '%{packager}'
      packager = "#{Etc::getpwnam(Etc::getlogin).gecos} <#{Etc::getlogin}@#{Socket::gethostname}>"
    end

    packager
  end

  TEMPLATE = File.read File.join(File.dirname(__FILE__), '..', 'templates', "#{Distro.nature.to_s}.spec.erb")
end

# Local Variables:
# ruby-indent-level: 2
# End:
