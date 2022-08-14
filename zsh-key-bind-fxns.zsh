#_
_fzf_fd1() {

	local dir
	dir=$(find ${1:-.} -path '*/\.*' -prune \
		-o -type d -print 2>/dev/null | fzf +m) &&
		cd "$dir"
}

# Select child directory and cd to it
__fzf_cd_child_dir() {
	DIR=$(find * -maxdepth 0 -type d -print 2>/dev/null | fzf --reverse) && cd "$DIR"
}

# Select parent directory and cd to it
__fzf_cd_parent_dir() {
	local declare dirs=()
	get_parent_dirs() {
		if [[ -d "${1}" ]]; then dirs+=("$1"); else return; fi
		if [[ "${1}" == '/' ]]; then
			for _dir in "${dirs[@]}"; do echo $_dir; done
		else
			get_parent_dirs $(dirname "$1")
		fi
	}
	local DIR=$(get_parent_dirs $(realpath "${1:-$PWD}") | fzf-tmux --tac)
	cd "$DIR"
}

# Command History
__fzf_history_widget() {
	local selected num
	setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2>/dev/null
	selected=($(fc -rl 1 | perl -ne 'print if !$seen{(/^\s*[0-9]+\**\s+(.*)/, $1)}++' |
		FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort,ctrl-z:ignore $FZF_CTRL_R_OPTS --query=${LBUFFER} +m" $(__fzfcmd)))
	local ret=$?
	if [ -n "$selected" ]; then
		num=$selected[1]
		if [ -n "$num" ]; then
			zle vi-fetch-history -n $num
		fi
	fi
	zle reset-prompt
	return $ret
}

#
__fzf_command_history1() {
	eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
}

#
__fzf_ag1() {
	[[ -n $1 ]] && cd $1 # go to provided folder or noop
	typeset AG_DEFAULT_COMMAND="ag -i -l --hidden"
	typeset IFS=$'\n'
	typeset selected=($(
		fzf \
			-m \
			-e \
			--ansi \
			--disabled \
			--reverse \
			--print-query \
			--bind "change:reload:$AG_DEFAULT_COMMAND {q} || true" \
			--preview "ag -i --color --context=2 {q} {}"
	))
	[ -n "$selected" ] && ${EDITOR} -c "/\\c${selected[0]}" ${selected[1]}
}

#
__vim_file_line() {
	file="$1"
	line="$2"
	read -r file line <<<"$(ag --nobreak --noheading $@ | fzf -0 -1 | awk -F: '{print $1, $2}')"

	if [[ -n $file ]]; then
		vim $file +$line
	fi
}

# Search File Contents and open selection in editor
__fzf_search_file_contents() {
	RG_DEFAULT_COMMAND="rg -i -l \
        --ignore-file tmp \
        --ignore-file .cache \
        --ignore-file '*/.cache/*' \
        --ignore-file '.cache/*' \
        --ignore-file vendor \
        --ignore-file .git \
        --ignore-file build \
        --ignore-file build-meson \
"
	read -r file line <<<$(fzf -0 -1 \
		--color 'fg:#bbccdd,fg+:#ddeeff,bg:#334455,preview-bg:#223344,border:#778899' \
		-e \
		--ansi \
		--disabled \
		--reverse \
		--border=sharp \
		--preview-window right,65% \
		--bind "change:reload:$RG_DEFAULT_COMMAND {q} || true" \
		--preview "rg -i --pretty --context 2 {q} {}|awk -F: '{print \$1, \$2}'" < <(rg --files))
	[[ -n "$file" ]] && vim "${file}" +$line </dev/tty
}

# Select and Load kfc palette
__fzf_kfc_select_palette() {
	kfc -s >/dev/tty
}

# Load Random kfc palette
__fzf_kfc_random_palette() {
	kfc -r >/dev/tty 2>/dev/null
}

# View Current zsh Key Binds and Bind Functions
__fzf_key_bind_report() {
	__get_key_bind_report >/dev/tty
}

# Select subdirectory and copy it to clipboard
__fzf_select_path_copy_to_clipboard() {
	local cmd="${FZF_CTRL_T_COMMAND:-"command find -L . -mindepth 1 \\( -path '*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' -o -fstype 'proc' \\) -prune \
    -o -type f -print \
    -o -type d -print \
    -o -type l -print 2> /dev/null | cut -b3-"}"
	setopt localoptions pipefail no_aliases 2>/dev/null
	local item
	eval "$cmd" | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} --reverse --bind=ctrl-z:ignore $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS" $(__fzfcmd) -m "$@" | while read item; do
		tty-copy -n "${item}"
	done
	local ret=$?
	echo
	return $ret
}

# Select binRick Meson Repo Directory and cd to it
__fzf_select_binrick_meson_repo() {
	grep binRick */.git/config | grep 'url =' | tr -s ' ' '\n' | grep 'binRick/' | gsed 's|https://github.com||g' | gsed 's|ssh://git@github.com/||g' | gsed 's|git@github.com:||g' | gsed 's|ssh://||g' | gsed 's/\.git$//g' |
		gsed 's/^\///g' |
		cut -d'/' -f2 | sort -u | while read -r d; do
		if [[ -f ~/repos/$d/meson.build ]]; then
			echo $d
		fi
	done | fzf --reverse | while read -r d; do
		[[ -d "$d" ]] && cd "$d"
	done
	true
}

# Execute make menu in git dir
__fzf_make_menu() {
	dir="$(command git rev-parse --show-toplevel 2>/dev/null)"
	[[ ! -d "$dir/.git" || ! -f "$dir/Makefile" ]] && return
	lastdir="$PWD"
	if [[ "$dir" != "$PWD" ]]; then
		lastdir="$PWD"
		cd "$dir"
	fi
	cmd="make menu; cd $lastdir"
	eval "$cmd"
}

# Change Directory to ~/repos/c_deps
__fzf_cd_c_deps() {
	cd ~/repos/c_deps && clear
}

# Most commonly cd directories
__fzf_commonly_cd_dirs() {
	cat ~/.config/zsh/dirs.log | cut -d: -f3 | sort | uniq -c | sort -k1 -r | tr -s ' ' | sed 's/^[[:space:]]//g' | cut -d' ' -f2-100 | head -n10
}

# Most commonly edited files
__fzf_commonly_edited_files() {
	egrep ';vi |;vim |;nvim |;v ' ~/.zsh_history | cut -d';' -f2 | cut -d' ' -f2-100 | sort | uniq -c | sort -k1 -r | tr -s ' ' | sed 's/^[[:space:]]//g' | cut -d' ' -f2-100 | head -n10
}

# Command History
__fzf_command_history() {
	local selected num
	setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2>/dev/null
	selected=($(fc -rl 1 | perl -ne 'print if !$seen{(/^\s*[0-9]+\**\s+(.*)/, $1)}++' |
		FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort,ctrl-z:ignore $FZF_CTRL_R_OPTS --query=${LBUFFER} +m" fzf))
	local ret=$?
	if [ -n "$selected" ]; then
		num=$selected[1]
		if [ -n "$num" ]; then
			zle vi-fetch-history -n $num
		fi
	fi
	zle reset-prompt
	return $ret
}
