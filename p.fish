function p --description 'create and enter a project in ~/sync/projects'
	set -l base ~/sync/projects

	if not test -d $base
		echo "p: $base does not exist" >&2
		return 1
	end

	if test (count $argv) -gt 1
		echo "p: too many arguments" >&2
		return 1
	end

	if test (count $argv) -eq 0
		cd $base
		return
	end

	set -l name $argv[1]

	if test -z "$name"; or string match -q '*/*' -- $name; or contains -- $name . ..
		echo "p: invalid project name: '$name'" >&2
		return 1
	end

	if test -d $base/$name
		echo (set_color red --bold)"p: PROJECT ALREADY EXISTS: $name"(set_color normal) >&2
	else
		mkdir $base/$name; or return 1
	end

	cd $base/$name
end
