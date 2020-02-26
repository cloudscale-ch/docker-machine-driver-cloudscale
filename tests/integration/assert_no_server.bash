machine_count="$(docker-machine ls -q --filter name="$MACHINE_NAME" | wc -l)"
[ "$machine_count" -eq 0 ]
