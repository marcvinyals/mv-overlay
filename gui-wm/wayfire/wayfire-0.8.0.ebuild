# Copyright 2019-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
RESTRICT="mirror"

inherit meson toolchain-funcs

DESCRIPTION="compiz like 3D wayland compositor"
HOMEPAGE="https://github.com/WayfireWM/wayfire"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/WayfireWM/${PN}.git"
else
	SRC_URI="https://github.com/WayfireWM/${PN}/releases/download/v${PV}/${P}.tar.xz"
	KEYWORDS="amd64 ~arm64 ~riscv ~x86"
fi

LICENSE="MIT"
SLOT="0"
IUSE="debug +gles +system-wfconfig +system-wlroots X"

DEPEND="
	dev-cpp/nlohmann_json
	dev-libs/libinput:=
	dev-libs/wayland
	gui-libs/gtk-layer-shell
	media-libs/glm
	media-libs/mesa:=[gles2,wayland,X?]
	media-libs/libglvnd[X?]
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/freetype:=[X?]
	x11-libs/libdrm
	x11-libs/gtk+:3=[wayland,X?]
	x11-libs/cairo[X?,svg(+)]
	x11-libs/libxkbcommon[X?]
	x11-libs/pango
	x11-libs/pixman
	X? (
		x11-base/xwayland
		x11-libs/libxcb
	)
	system-wfconfig? (
		>=gui-libs/wf-config-${PV}
	)
	!system-wfconfig? ( !gui-libs/wf-config )
	system-wlroots? (
		gui-libs/wlroots:0/16[X?]
	)
	!system-wlroots? ( !gui-libs/wlroots )
"

RDEPEND="
	${DEPEND}
	x11-misc/xkeyboard-config
"

BDEPEND="
	dev-libs/wayland-protocols
	virtual/pkgconfig
"

src_configure() {
	sed -e "s:@EPREFIX@:${EPREFIX}:" \
		"${FILESDIR}"/wayfire-session > "${T}"/wayfire-session || die
	sed -e "s:@EPREFIX@:${EPREFIX}:" \
		"${FILESDIR}"/wayfire-session.desktop > "${T}"/wayfire-session.desktop || die
	sed -i -e 's/git\.found[(][)]/false/' "${S}/meson.build"
	if ! use debug; then
		# These patches are necessary with -Ddebug_ipc=false
		local i
		for i in grid wm-actions scale single_plugins; do
			sed -i -e 's:, json::' "${S}/plugins/${i}/meson.build"
		done
	fi
	local emesonargs=(
		$(meson_feature system-wfconfig use_system_wfconfig)
		$(meson_feature system-wlroots use_system_wlroots)
		$(meson_feature X xwayland)
		$(meson_use gles enable_gles32)
		$(meson_use debug debug_ipc)
		$(usex debug --buildtype=debug "")
		$(usex debug -Db_sanitize=address,undefined "")
	)

	# Clang will fail to link without this
	tc-is-clang && emesonargs+=( $(usex debug -Db_lundef=false "") )

	meson_src_configure
}

src_install() {
	meson_src_install
	rm -rf "${ED}"/usr/man || die
	dobin "${T}"/wayfire-session

	insinto "/usr/share/wayland-sessions/"
	insopts -m644
	doins wayfire.desktop
	doins "${T}"/wayfire-session.desktop

	insinto "/usr/share/wayfire/"
	doins wayfire.ini
}

pkg_postinst() {
	if [ -z "${REPLACING_VERSIONS}" ]; then
		elog "Wayfire has been installed but the session cannot be used"
		elog "until you install a configuration file. The default config"
		elog "file is installed at \"/usr/share/wayfire/wayfire.ini\""
		elog "To install the file execute"
		elog "\$ cp /usr/share/wayfire/wayfire.ini ~/.config/wayfire.ini"
	fi
}
