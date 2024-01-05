#!/bin/bash
# Script that creates a Team if it does not already exist, 

# Make sure TFE_TOKEN, TFE_ORG and TFE_ADDR  variables are set.
# **TFE_TOKEN** to owners team token. 
# **TFE_ORG** organization name for the respective TFE environment. 
# **TFE_ADDR** should be set to the FQDN/URL of the private TFE server.

if [ ! -z "$2" ]; then
  token=$2
  echo "TFE_TOKEN variable was found."
  echo $token
else
  echo "TFE_TOKEN variable was not set."
  echo "It should be a user or team token that has write or admin"
  echo "permission on the workspace."
  echo "Exiting."
  exit 1
fi

# Evaluate $TFE_ORG environment variable
# If not set, give error and exit
if [ ! -z "$TFE_ORG" ]; then
  organization=$TFE_ORG
  echo "TFE_ORG environment variable was set to ${TFE_ORG}."
  echo "Using organization, ${organization}."
else
  echo "You must export/set the TFE_ORG environment variable."
  echo "Exiting."
  exit
fi

# Evaluate $TFE_ADDR environment variable if it exists
# Otherwise, use "app.terraform.io"
# You should edit these before running the script.
if [ ! -z "$TFE_ADDR" ]; then
  address=$TFE_ADDR
  echo "TFE_ADDR environment variable was set to ${TFE_ADDR}."
  echo "Using address, ${address}"
else
  echo "You must export/set the TFE_ADDR environment variable."
  echo "Exiting."
  exit
fi


# You can change sleep duration if desired
sleep_duration=5


# Set team name if provided as the second argument
if [ ! -z "$1" ]; then
  teamname=$1
  echo "Using Team name provided as argument: " $teamname
else
  echo "You must provide the team name variable as an argument."
  echo "Exiting."
  exit
fi

# Make sure $teamname does not have spaces
if [[ "${teamname}" != "${teamname% *}" ]] ; then
    echo "The team name cannot contain spaces."
    echo "Please pick a name without spaces and run again."
    exit
fi


# Write out team.template.json
cat > teams.template.json <<EOF
{
  "data": {
    "type": "teams",
    "attributes": {
      "name": "placeholder",
      "terraform-version": "1.0.5",
      "organization-access": {
        "manage-workspaces": true
      }
    }
  }
}
EOF

#Set name of Team name in team.json
sed "s/placeholder/${teamname}/" < teams.template.json > teams.json

# Check to see if the workspace already exists
echo ""
echo "Checking to see if team exists"
response=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" "https://${address}/api/v2/organizations/${organization}/teams")


# Check if the request was successful
if [[ "$(echo "$response" | jq -r '.errors')" != "null" ]]; then
  echo "Error: Unable to list teams."
  echo "Error message: $(echo "$response" | jq -r '.errors[0].detail')"
  exit 1
fi

# Use jq to filter teams by name
team_id=$(echo "$response" | jq -r ".data[] | select(.attributes.name == \"${teamname}\") | .id")

if [[ -n "$team_id" ]]; then
  echo "Team already existed."
  echo "Team ID for $TEAM_NAME: $team_id"
else
  echo "No team found with the name '${teamname}'; will create it."
  team_result=$(curl -s --header "Authorization: Bearer $TFE_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @teams.json "https://${address}/api/v2/organizations/${organization}/teams")
  team_id=$(echo "$team_result" | jq -r ".data.id")
  echo "Created Team ID: $team_id"

fi

rm teams.template.json
rm teams.json

echo "Finished"