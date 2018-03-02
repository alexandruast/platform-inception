gicu() { git add -A && git commit -m "${*:-Work in progress}" && git push; }
g() {
  case $1 in
    b) shift; git branch "$@" ;;
    c) shift; git checkout "$@" ;;
    l) git pull ;;
    s) git status ;;
    *) git "$@" ;;
  esac
}