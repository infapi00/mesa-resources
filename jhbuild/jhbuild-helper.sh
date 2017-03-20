usage()
{
    echo -e "\e[31mUSAGE:"
    echo -e "\e[31m$0 <option>"
    echo "            Options:i965|nouveau|nvidia|radeon|amd"
}

BASE_PATH="`dirname \"$0\"`"
FULL_SCRIPT_PATH=$(readlink -f $0)
FULL_BASE_PATH="`dirname \"$FULL_SCRIPT_PATH\"`"

if ! [ $1 ]
then
    usage
    exit -1
fi

GL_DRIVER="${1}"
shift

case "x${GL_DRIVER}" in
"xi965" | "xnouveau" | "xnvidia" | "xradeon" | "xamd" )
    export -p GL_DRIVER
    ;;
*)
    usage
    exit -2
    ;;
esac

if [ -f "${FULL_BASE_PATH}/JHBUILD_CONFIG" ]; then
    source "${FULL_BASE_PATH}/JHBUILD_CONFIG"
fi

if [ -z ${JHBUILD_MESA_ROOT} ]; then
    JHBUILD_MESA_ROOT="${FULL_BASE_PATH}"
fi
export -p JHBUILD_MESA_ROOT

if [ ! -z ${MESA_RESOURCES} ]; then
    export -p MESA_RESOURCES
fi
