module Bundler
  def self.with_friendly_errors
    yield
  rescue Bundler::BundlerError => e
    Bundler.ui.error e.message, :wrap => true
    Bundler.ui.trace e
    exit e.status_code
  rescue Thor::Error => e
    Bundler.ui.error e.message
    exit 1
  rescue LoadError => e
    raise e unless e.message =~ /cannot load such file -- openssl|openssl.so|libcrypto.so/
    Bundler.ui.error "\nCould not load OpenSSL."
    Bundler.ui.warn "You must recompile Ruby with OpenSSL support or change the sources in your" \
      "\nGemfile from 'https' to 'http'. Instructions for compiling with OpenSSL" \
      "\nusing RVM are available at rvm.io/packages/openssl."
    Bundler.ui.trace e
    exit 1
  rescue Interrupt => e
    Bundler.ui.error "\nQuitting..."
    Bundler.ui.trace e
    exit 1
  rescue SystemExit => e
    exit e.status
  rescue Exception => e
    Bundler.ui.error <<-ERR, :wrap => true
      Unfortunately, a fatal error has occurred. Please see the Bundler
      troubleshooting documentation at http://bit.ly/bundler-issues. Thanks!

    ERR
    raise e
  end
end
