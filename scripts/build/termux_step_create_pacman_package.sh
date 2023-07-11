termux_step_create_pacman_package() {
	local TERMUX_PKG_INSTALLSIZE
	TERMUX_PKG_INSTALLSIZE=$(du -bs . | cut -f 1)

	# From here on TERMUX_ARCH is set to "all" if TERMUX_PKG_PLATFORM_INDEPENDENT is set by the package
	[ "$TERMUX_PKG_PLATFORM_INDEPENDENT" = "true" ] && TERMUX_ARCH=any

	# Configuring the selection of a compress for a batch.
	source "${TERMUX_SCRIPTDIR}/utils/package/package.sh"
	local TERMUX_PACMAN_COMPRESS
	local TERMUX_PACPAM_PKG_SUFFIX
	package__set_pacman_compress_env
	local TERMUX_BUILT_PACKAGE_FILENAME
	package__set_built_package_filename_env "$TERMUX_PKG_NAME" "$TERMUX_PKG_FULLVERSION_FOR_PACMAN" "$TERMUX_ARCH" "pacman" "$DEBUG" "$TERMUX_PACPAM_PKG_SUFFIX"
	local PACMAN_FILE="${TERMUX_OUTPUT_DIR}/${TERMUX_BUILT_PACKAGE_FILENAME}"

	local BUILD_DATE
	BUILD_DATE=$(date +%s)

	# Package metadata.
	{
		echo "pkgname = $TERMUX_PKG_NAME"
		echo "pkgbase = $TERMUX_PKG_NAME"
		echo "pkgver = $TERMUX_PKG_FULLVERSION_FOR_PACMAN"
		echo "pkgdesc = $(echo "$TERMUX_PKG_DESCRIPTION" | tr '\n' ' ')"
		echo "url = $TERMUX_PKG_HOMEPAGE"
		echo "builddate = $BUILD_DATE"
		echo "packager = $TERMUX_PKG_MAINTAINER"
		echo "size = $TERMUX_PKG_INSTALLSIZE"
		echo "arch = $TERMUX_ARCH"

		if [ -n "$TERMUX_PKG_LICENSE" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_LICENSE" | awk '{ printf "license = %s\n", $0 }'
		fi

		if [ -n "$TERMUX_PKG_REPLACES" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_REPLACES" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "replaces = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }'
		fi

		if [ -n "$TERMUX_PKG_CONFLICTS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_CONFLICTS" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "conflict = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }'
		fi

		if [ -n "$TERMUX_PKG_BREAKS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_BREAKS" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "conflict = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }'
		fi

		if [ -n "$TERMUX_PKG_PROVIDES" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_PROVIDES" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "provides = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }'
		fi

		if [ -n "$TERMUX_PKG_DEPENDS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_DEPENDS" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "depend = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }' | sed 's/|.*//'
		fi

		if [ -n "$TERMUX_PKG_RECOMMENDS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_RECOMMENDS" | awk '{ printf "optdepend = %s\n", $1 }'
		fi

		if [ -n "$TERMUX_PKG_SUGGESTS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_SUGGESTS" | awk '{ printf "optdepend = %s\n", $1 }'
		fi

		if [ -n "$TERMUX_PKG_BUILD_DEPENDS" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_BUILD_DEPENDS" | sed 's|(||g; s|)||g; s| ||g; s|>>|>|g; s|<<|<|g' | awk '{ printf "makedepend = " $1; if ( ($1 ~ /</ || $1 ~ />/ || $1 ~ /=/) && $1 !~ /-/ ) printf "-0"; printf "\n" }'
		fi

		if [ -n "$TERMUX_PKG_CONFFILES" ]; then
			tr ',' '\n' <<< "$TERMUX_PKG_CONFFILES" | awk '{ printf "backup = '"${TERMUX_PREFIX:1}"'/%s\n", $1 }'
		fi

		if [ -n "$TERMUX_PKG_GROUPS" ]; then
			tr ',' '\n' <<< "${TERMUX_PKG_GROUPS/#, /}" | awk '{ printf "group = %s\n", $1 }'
		fi
	} > .PKGINFO

	# Build metadata.
	{
		echo "format = 2"
		echo "pkgname = $TERMUX_PKG_NAME"
		echo "pkgbase = $TERMUX_PKG_NAME"
		echo "pkgver = $TERMUX_PKG_FULLVERSION_FOR_PACMAN"
		echo "pkgarch = $TERMUX_ARCH"
		echo "packager = $TERMUX_PKG_MAINTAINER"
		echo "builddate = $BUILD_DATE"
	} > .BUILDINFO

	# Write installation hooks.
	termux_step_create_debscripts
	termux_step_create_pacman_install_hook

	# Create package
	shopt -s dotglob globstar
	printf '%s\0' **/* | bsdtar -cnf - --format=mtree \
		--options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \
		--null --files-from - --exclude .MTREE | \
		gzip -c -f -n > .MTREE
	printf '%s\0' **/* | bsdtar --no-fflags -cnf - --null --files-from - | \
		$TERMUX_PACMAN_COMPRESS > "$PACMAN_FILE"
	shopt -u dotglob globstar
}
