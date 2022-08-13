[[ -o interactive ]] || return 0

__bind_control_key_function() {
	local KEY="$1"
	shift
	local FXN="$@"
	local CMD=$(
		cat <<EOF
    zle     -N               $FXN
    bindkey -M emacs '^$KEY' $FXN
    bindkey -M vicmd '^$KEY' $FXN
    bindkey -M viins '^$KEY' $FXN
EOF
	)
	eval "$CMD"
}

export LAST_CWD="$(pwd)"
function log_cwd_change() {
	[[ -d "$(dirname $__DIRS_FILE)" ]] || mkdir -p "$(dirname $__DIRS_FILE)"
	printf "%s:%s:%s\n" \
		"$(date +%s)" \
		"$LAST_CWD" \
		"$PWD" \
		>>$__DIRS_FILE
}

__kfc_bin="$(command -v kfc)"
function load_kfc_profile() {
	cmd="$__kfc_bin -p '$(basename "$PWD")'"
	[[ -e "$__kfc_bin" ]] && eval "$cmd" 2>/dev/null
}

function rename_tab() {
	local p="${PWD/#"$HOME"/~}"
	window_title="\e]0;${p}\a"
	printf "%s" "$window_title"
}

function __zsh_precmd_hook() {
	if [[ "$LAST_CWD" != "$PWD" ]]; then
		log_cwd_change
		rename_tab
		load_kfc_profile
		LAST_CWD="$PWD"
	fi
	true
}

__load_zsh_precmd_hook() {
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd __zsh_precmd_hook
}

__bind_control_keys() {
	. ~/.zsh-key-bind-config.sh
	. ~/.zsh-key-bind-utils.sh
	. ~/.zsh-key-bind-fxns.sh
	__bind_control_key_function B $CONTROL_B_HANDLER
	__bind_control_key_function G $CONTROL_G_HANDLER
	__bind_control_key_function H $CONTROL_H_HANDLER
	__bind_control_key_function J $CONTROL_J_HANDLER
	__bind_control_key_function T $CONTROL_T_HANDLER
	__bind_control_key_function N $CONTROL_N_HANDLER
	__bind_control_key_function O $CONTROL_O_HANDLER
	__bind_control_key_function U $CONTROL_U_HANDLER
	__bind_control_key_function V $CONTROL_V_HANDLER
	__bind_control_key_function W $CONTROL_W_HANDLER
	__bind_control_key_function R $CONTROL_R_HANDLER
}
#####################
main() {
	__bind_control_keys
	__load_zsh_precmd_hook
}
#####################
main
