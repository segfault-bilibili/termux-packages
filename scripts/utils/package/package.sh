# shellcheck shell=sh
# shellcheck disable=SC2039,SC2059

# Title:          package
# Description:    A library for package utils.



##
# Check if package on device builds are supported by checking
# `$TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED` value in its `build.sh`
# file.
# .
# .
# **Parameters:**
# `package_dir` - The directory path for the package `build.sh` file.
# .
# **Returns:**
# Returns `0` if supported, otherwise `1`.
# .
# .
# package__is_package_on_device_build_supported `package_dir`
##
package__is_package_on_device_build_supported() {
	[ $(. "${1}/build.sh"; echo "$TERMUX_PKG_ON_DEVICE_BUILD_NOT_SUPPORTED") != "true" ]
	return $?
}



##
# Get built package filename
# .
# .
# **Parameters:**
# `package_name` - The package name.
# `package_version` - The package version.
# `package_arch` - Architecture of the package, must be one of supported_architectures defined below
# `package_format` - Format of the package, must be one of supported_package_formats defined below
# `package_dbg` - Whether the package is a debug build, "true" or "-dbg" if so, anything else if not
# `package_compress` - Compression used in pacman format, ignored if the package format is not pacman.
#                      Defaults to "xz". If an unknown compression is specified, it also defaults to "xz".
# .
# **Environment variables:**
# `TERMUX_BUILT_PACKAGE_FILENAME` - Will be set to corresponding built package filename.
#                                   Please use local declaration for such variable before calling this function.
# .
# **Returns:**
# Returns `0` if successful, otherwise `1`.
# .
# .
# local TERMUX_BUILT_PACKAGE_FILENAME
# package__set_built_package_filename_env "`package_name`" "`package_version`" "`package_arch`" "`package_format`" "`package_dbg`" "`package_compress`"
##
package__set_built_package_filename_env() {
	local supported_architectures=("aarch64" "arm" "i686" "x86_64")
	local supported_package_formats=("apt" "pacman")

	local package_name=$1
	local package_version=$2
	local package_arch=$3
	local package_format=$4
	local package_dbg=$(if [[ "$5" == "true" ]] || [[ "$5" == "-dbg" ]]; then echo "-dbg"; fi)
	local package_compress=$6

	if [[ " ${supported_architectures[*]} " != *" $package_arch "* ]]; then
		echo "Unsupported architecture '$package_arch'" 1>&2
		echo "Supported architectures: '${supported_architectures[*]}'" 1>&2
		return 1
	fi

	if [[ " ${supported_package_formats[*]} " != *" $package_format "* ]]; then
		echo "Unsupported package format '$package_format'" 1>&2
		echo "Supported package formats: '${supported_package_formats[*]}'" 1>&2
		return 1
	fi

	if [[ "$package_format" == "pacman" ]]; then
		local TERMUX_PACMAN_COMPRESS
		local TERMUX_PACPAM_PKG_SUFFIX
		package__set_pacman_compress_env $package_compress
	fi

	case "$package_format" in
		"apt") TERMUX_BUILT_PACKAGE_FILENAME="${package_name}${package_dbg}_${package_version}_${package_arch}.deb";;
		"pacman") TERMUX_BUILT_PACKAGE_FILENAME="${package_name}${package_dbg}-${package_version}-${package_arch}.pkg.tar.${TERMUX_PACPAM_PKG_SUFFIX}";;
	esac

	return 0
}



##
# Set environment variables for pacman compress
# .
# .
# **Parameters:**
# `package_compress` - Compression used in pacman format, ignored if the package format is not pacman.
#                      Defaults to "xz". If an unknown compression is specified, it also defaults to "xz".
# .
# **Environment variables:**
# `TERMUX_PACMAN_COMPRESS` - Will be set to corresponding compress command.
#                            Please use local declaration for such variable before calling this function.
# `TERMUX_PACPAM_PKG_SUFFIX` - Will be set to corresponding filename suffix
#                              Please use local declaration for such variable before calling this function.
# .
# **Returns:**
# Returns `0` if successful.
# .
# .
# local TERMUX_PACMAN_COMPRESS
# local TERMUX_PACPAM_PKG_SUFFIX
# package__set_pacman_compress_env `package_compress`
##
package__set_pacman_compress_env() {
	local package_compress=$1
	case $package_compress in
		"gzip")
			TERMUX_PACMAN_COMPRESS=(gzip -c -f -n)
			TERMUX_PACPAM_PKG_SUFFIX="gz";;
		"bzip2")
			TERMUX_PACMAN_COMPRESS=(bzip2 -c -f)
			TERMUX_PACPAM_PKG_SUFFIX="bz2";;
		"zstd")
			TERMUX_PACMAN_COMPRESS=(zstd -c -z -q -)
			TERMUX_PACPAM_PKG_SUFFIX="zst";;
		"lrzip")
			TERMUX_PACMAN_COMPRESS=(lrzip -q)
			TERMUX_PACPAM_PKG_SUFFIX="lrz";;
		"lzop")
			TERMUX_PACMAN_COMPRESS=(lzop -q)
			TERMUX_PACPAM_PKG_SUFFIX="lzop";;
		"lz4")
			TERMUX_PACMAN_COMPRESS=(lz4 -q)
			TERMUX_PACPAM_PKG_SUFFIX="lz4";;
		"lzip")
			TERMUX_PACMAN_COMPRESS=(lzip -c -f)
			TERMUX_PACPAM_PKG_SUFFIX="lz";;
		"xz" | *)
			TERMUX_PACMAN_COMPRESS=(xz -c -z -)
			TERMUX_PACPAM_PKG_SUFFIX="xz";;
	esac
	return 0
}



##
# Check if a specific version of a package has been built by checking
# whether the corresponding built package file of any arch or format
# exists in `$TERMUX_OUTPUT_DIR/` directory.
# .
# .
# **Parameters:**
# `package_name` - The package name for the package.
# `package_version` - The package version for the package to check.
# .
# **Returns:**
# Returns `0` if built, otherwise `1`.
# .
# .
# package__is_package_version_built "`package_name`" "`package_version`"
##
package__is_package_version_built() {
	local dbg_or_not=("false" "true")
	local supported_architectures=("aarch64" "arm" "i686" "x86_64")
	local supported_package_formats=("apt" "pacman")
	local supported_compressions=("xz" "gzip" "bzip2" "zstd" "lrzip" "lzop" "lz4" "lzip")

	local package_name=$1
	local package_version=$2

	local TERMUX_BUILT_PACKAGE_FILENAME
	local package_dbg
	local package_format
	local package_arch
	local package_compress

	for package_dbg in "${dbg_or_not[@]}"; do
		for package_format in "${supported_package_formats[@]}"; do
			for package_arch in "${supported_architectures[@]}"; do
				TERMUX_BUILT_PACKAGE_FILENAME=""
				if [[ "$package_format" == "pacman" ]]; then
					for package_compress in "${supported_compressions[@]}"; do
						package__set_built_package_filename_env "$package_name" "$package_version" "$package_arch" "$package_format" \
							"$package_dbg" "$package_compress"
						[ -f "${TERMUX_OUTPUT_DIR}/${TERMUX_BUILT_PACKAGE_FILENAME}" ] && return 0
					done
				else 
					package__set_built_package_filename_env "$package_name" "$package_version" "$package_arch" "$package_format" \
						"$package_dbg"
					[ -f "${TERMUX_OUTPUT_DIR}/${TERMUX_BUILT_PACKAGE_FILENAME}" ] && return 0
				fi
			done
		done
	done

	return 1
}
