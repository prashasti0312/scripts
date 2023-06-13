#!/bin/bash

# Get the list of running Docker container IPs
container_ips=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' $(docker ps -q))
echo "$container_ips"

# Create an array to store unique IPs
unique_ips=()

# Create an array to store duplicate IPs
duplicate_ips=()

# Loop through each container IP
for ip in $container_ips; do
    # Flag to check if IP is already in unique_ips array
    is_duplicate=false

    # Loop through each unique IP to check for duplicates
    for unique_ip in "${unique_ips[@]}"; do
        if [[ "$ip" == "$unique_ip" ]]; then
            is_duplicate=true
            break
        fi
    done

    # Check if IP is a duplicate or not
    if [[ "$is_duplicate" == true ]]; then
        duplicate_ips+=("$ip")
    else
        unique_ips+=("$ip")
    fi
done

echo "Unique IPs: ${unique_ips[@]}"
echo "Duplicate IPs: ${duplicate_ips[@]}"

# Check if there are any duplicate IPs
if [[ ${#duplicate_ips[@]} -ge 1 ]]; then
    echo "Duplicate IPs found: ${duplicate_ips[@]}"

    # Loop through each duplicate IP
    for ip in "${duplicate_ips[@]}"; do
        # Get the container IDs with the duplicate IP
        container_ids=$(docker ps -q --filter "status=running" | xargs docker inspect -f '{{.Id}} {{.NetworkSettings.IPAddress}}' | awk -v ip="$ip" '$2==ip {print $1}')
        echo $container_ids
        # Redeploy the services by restarting the containers
        echo "Redeploying services with IP: $ip"
        for container_id in $container_ids; do
            #curl --unix-socket /var/run/docker.sock http:/v1.24/containers/f26f67feb79a/json | jq -r '.Config.Labels."com.amazonaws.ecs.task-definition-family", .Config.Labels."com.amazonaws.ecs.task-definition-version"'
            #echo "Restarted container: $container_id"
	    response=$(curl --unix-socket /var/run/docker.sock http:/v1.24/containers/$container_id/json)
	    #task_definition_family=$(echo "$response" | jq -r '.Config.Labels["com.amazonaws.ecs.task-definition-family"]')
            #task_definition_version=$(echo "$response" | jq -r '.Config.Labels["com.amazonaws.ecs.task-definition-version"]')
	    cluster=$(echo "$response" | jq -r '.Config.Labels["com.amazonaws.ecs.cluster"]')
	    task_definition_arn=$(echo "$response" | jq -r '.Config.Labels["com.amazonaws.ecs.task-arn"]')
            aws ecs stop-task --region ap-south-1 --cluster $cluster --task $task_definition_arn
        done
    done
else
    echo "No duplicate IPs found."
fi
