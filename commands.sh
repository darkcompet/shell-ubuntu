#!/bin/bash
set -euo pipefail

Docker() {
	case "$1" in
		# --- Image ---
		# Remove image (force remove if used by container)
		"image-remove")
			docker rmi -f $2 ;;
		# Remove all unused images
		"images-prune")
			docker image prune -a -f ;;

		# --- Container ---
		# Access to container shell
		"container-shell")
			docker exec -it $2 sh ;;
		# Remove container (force stop if running)
		"container-remove")
			docker rm -f $2 ;;
		# Remove all stopped containers
		"containers-prune")
			docker container prune -f ;;

		# --- Volume ---
		# List volumes
		"volumes")
			docker volume ls ;;
		# Remove unused volumes
		"volumes-prune")
			docker volume prune -f ;;

		# --- Network ---
		# List networks
		"networks")
			docker network ls ;;
		# Inspect network
		"network-inspect")
			docker network inspect $2 ;;
		# Remove network
		"network-remove")
			docker network rm $2 ;;
		# Remove unused networks
		"networks-prune")
			docker network prune -f ;;

		# --- System ---
		# System details
		"system")
			docker system df -v ;;
		# Reset all (delete all image/container/network/volume/cache/...)
		"system-reset")
			read -p "Are you sure? This will delete everything! (y/N): " ans
			if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
				echo "Aborted."
				return 1  # use exit 1 if running as a standalone script
			fi

			docker system prune -a --volumes -f ;;

		# --- Default ---
		*)
			echo "Docker command with arguments:"
			echo "  image-remove IMAGE_ID|IMAGE_NAME"
			echo "  images-prune"
			echo "  container-shell CONTAINER_ID|CONTAINER_NAME"
			echo "  container-remove CONTAINER_ID|CONTAINER_NAME"
			echo "  containers-prune"
			echo "  volumes"
			echo "  volumes-prune"
			echo "  networks"
			echo "  network-inspect NETWORK_ID|NETWORK_NAME"
			echo "  network-remove NETWORK_ID|NETWORK_NAME"
			echo "  networks-prune"
			echo "  system-details"
			echo "  system-reset" ;;
	esac
}
