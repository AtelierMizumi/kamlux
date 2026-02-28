pkgname=kamlux
pkgver=1.0.0
pkgrel=1
pkgdesc="Automatic screen brightness adjustment for KDE Plasma using camera-based ambient light detection"
arch=('any')
url="https://github.com/AtelierMizumi/kamlux"
license=('MIT')
depends=('python' 'v4l-utils' 'qtchooser')
optdepends=('plasma-desktop: for KDE Plasma integration')
makedepends=('git')
provides=('kamlux')
conflicts=('kamlux')
source=("kamlux-${pkgver}.tar.gz::https://github.com/AtelierMizumi/kamlux/archive/v${pkgver}.tar.gz")
sha256sums=('SKIP')

package() {
    install_dir="$pkgdir/usr/share/kamlux"
    config_dir="$pkgdir/etc/kamlux"
    bin_dir="$pkgdir/usr/bin"
    
    # Create directories
    mkdir -p "$install_dir"
    mkdir -p "$config_dir"
    mkdir -p "$bin_dir"
    
    # Install main script
    install -Dm755 "kamlux-${pkgver}/src/kamlux.py" "${install_dir}/kamlux.py"
    
    # Install default config
    install -Dm644 "kamlux-${pkgver}/src/config.json" "${config_dir}/config.json"
    
    # Install launcher
    install -Dm755 <<EOF > "${bin_dir}/kamlux"
#!/usr/bin/env bash
exec python3 /usr/share/kamlux/kamlux.py "\$@"
EOF
    
    # Install man page (if exists)
    if [ -f "kamlux-${pkgver}/docs/kamlux.1" ]; then
        install -Dm644 "kamlux-${pkgver}/docs/kamlux.1" "${pkgdir}/usr/share/man/man1/kamlux.1"
    fi
    
    # Install systemd service (system-wide)
    mkdir -p "$pkgdir/usr/lib/systemd/user"
    install -Dm644 "kamlux-${pkgver}/systemd/kamlux.service" "${pkgdir}/usr/lib/systemd/user/kamlux.service"
}
