. ~/.zsh-key-bind-config.sh

runcmd() { perl -e 'ioctl STDOUT, 0x5412, $_ for split //, <>'; }

writecmd() { perl -e 'ioctl STDOUT, 0x5412, $_ for split //, do{ chomp($_ = <>); $_ }'; }

__fzfcmd() {
	[ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
		echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

__read_key_bind_config_items() { grep '^CONTROL_' $KEY_BIND_CONFIG_FILE; }

__read_key_bind_keys() {
	cut -d '_' -f2 <(__read_key_bind_config_items) | sort -u
}

__get_key_bind_fxn_desc() {
	FXN="$1"
	desc="$(grep "${FXN}()" $KEY_BIND_FXNS_FILE -B 1 | grep '^#' | cut -d '#' -f2-100 | sed 's/^[[:space:]]//g')"
	desc="${desc:-No Description}"
	printf "%s\n" "$desc"
}

__read_key_bind_key_fxns() {
	while IFS='=' read -r var fxn; do
		key=$(echo $var | cut -d'_' -f2)
		desc="$(__get_key_bind_fxn_desc "$fxn")"
		printf "%s=%s\n" "$key" "$fxn"
	done < <(__read_key_bind_config_items)
}

__get_key_bind_fxn() {
	KEY="$1"
	grep "CONTROL_${KEY}_HANDLER=" $KEY_BIND_CONFIG_FILE | cut -d= -f2
}

__get_key_bind_fxns() {
	cut -d '=' -f2 <(__read_key_bind_config_items) | sort -u
}

__get_key_bind_fxn_key() {
	FXN="$1"
	cut -d= -f1 < <(grep "=${FXN}$" $KEY_BIND_CONFIG_FILE) | cut -d '_' -f2
}

__get_bind_fxns() {
	{ grep '^__fzf_.*()' | cut -d'(' -f1 | sort -u; } <$KEY_BIND_FXNS_FILE
}

__get_key_bind_report() {

	keys="$(__read_key_bind_keys | tr '\n' ' ')"
	key_binds="$(
		__read_key_bind_key_fxns | while IFS='=' read -r key fxn; do
			spaces="$((40 - $(echo $fxn | wc -c)))"
			desc="$(__get_key_bind_fxn_desc "$fxn")"
			printf " %s%s   [%s] %s\n" \
				"$(ansi -n --black --bg-green --italic "  Control")" \
				"$(ansi -n --black --bg-green --bold "  $key  ")" \
				"$(ansi -n --yellow --underline "$fxn")" \
				"$(ansi --forward=$spaces -n --green --italic "$desc")"
		done
	)"
	key_bind_fxns="$(
		__get_bind_fxns | xargs -I % echo -e "\t%"
	)"
	ansi -n --line=1
	clear
	kfc -p base16-pico
	printf "\n"
	printf "$(ansi -n --green "Key Bind Functions File")     : %s\n" "$(ansi -n --green $KEY_BIND_FXNS_FILE)"
	printf "$(ansi -n --green "Key Bind Config File")        : %s\n" "$(ansi -n --green $KEY_BIND_CONFIG_FILE)"
	printf "$(ansi -n --green "Bound Control Keys")         : %s\n" "$(ansi -n --yellow --bold --inverse "  $keys  ")"
	printf "\n$(ansi -n --green "Active Key Binds")\n%s\n" "$(ansi -n --green "$key_binds")"
	printf "\n$(ansi -n --green "Key Binds Functions")\n%s\n" "$(ansi -n --magenta "$key_bind_fxns")"
	printf "\n"
}

is_in_git_repo() {
	git rev-parse HEAD >/dev/null 2>&1
}

fzf-down() {
	fzf --height 50% --min-height 20 --border --bind ctrl-/:toggle-preview "$@"
}

___git_diff() {
	is_in_git_repo || return
	git -c color.status=always status --short |
		fzf-down -m --ansi --nth 2..,.. \
			--preview '(git diff --color=always -- {-1} | sed 1,4d; cat {-1})' |
		cut -c4- | sed 's/.* -> //'
}

_gb() {
	is_in_git_repo || return
	git branch -a --color=always | grep -v '/HEAD\s' | sort |
		fzf-down --ansi --multi --tac --preview-window right:70% \
			--preview 'git log --oneline --graph --date=short --color=always --pretty="format:%C(auto)%cd %h%d %s" $(sed s/^..// <<< {} | cut -d" " -f1)' |
		sed 's/^..//' | cut -d' ' -f1 |
		sed 's#^remotes/##'
}

_gt() {
	is_in_git_repo || return
	git tag --sort -version:refname |
		fzf-down --multi --preview-window right:70% \
			--preview 'git show --color=always {}'
}

_gh() {
	is_in_git_repo || return
	git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=always |
		fzf-down --ansi --no-sort --reverse --multi --bind 'ctrl-s:toggle-sort' \
			--header 'Press CTRL-S to toggle sort' \
			--preview 'grep -o "[a-f0-9]\{7,\}" <<< {} | xargs git show --color=always' |
		grep -o "[a-f0-9]\{7,\}"
}

_gr() {
	is_in_git_repo || return
	git remote -v | awk '{print $1 "\t" $2}' | uniq |
		fzf-down --tac \
			--preview 'git log --oneline --graph --date=short --pretty="format:%C(auto)%cd %h%d %s" {1}' |
		cut -d$'\t' -f1
}

_gs() {
	is_in_git_repo || return
	git stash list | fzf-down --reverse -d: --preview 'git show --color=always {1}' |
		cut -d: -f1
}

__view_zsh_fxn() {
	local fxn="$1"
	declare -f "$fxn"
}

__hash() {
	command md5sum | while read -r h l; do printf "%s\n" "$h"; done
}

__hash_zsh_fxn() {
	local fxn="$1"
	__view_zsh_fxn "$fxn" | __hash
}

__zsh_fxn_with_hash_suffix() {
	local fxn="$1"
	printf "%s_%s\n" "$fxn" "$(__hash_zsh_fxn "$fxn")"
}

__zsh_fxn_filename() {
	local fxn="$1"
	printf "%s/%s.zsh\n" "$__ZSH_KEY_BIND_CFG_DIR" "$(__zsh_fxn_with_hash_suffix "$fxn")"
}

__get_json_encoded_key_bind_fxns() {
	__read_key_bind_key_fxns | while IFS='=' read -r key fxn; do
		jo \
			key="$key" \
			fxn="$fxn" \
			fxn_hash="$(__zsh_fxn_with_hash_suffix "$fxn")" \
			fxn_file="$(__zsh_fxn_filename "$fxn")"
	done
}
