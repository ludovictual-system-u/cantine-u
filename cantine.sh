#!/bin/bash

EMAIL=$1
PASSWD=$2
WEBHOOK_URL=$3
TODAY=$(date +"%Y-%m-%d")

fn_auth () {

# Generate Auth Payload :
fn_payload_auth()
{
cat <<EOF
{"mail":"$EMAIL","password":"$PASSWD"}
EOF
}

# Get Bearer Token from SoHappy APIM API
AUTH_TOKEN=$(curl -s 'https://apim-production.so-happy.fr/api-app/tokens' \
 -X POST \
 -H 'Accept: application/json, text/plain, */*' \
 -H 'Ocp-Apim-Subscription-Key: 7d777a5c9c7a4def8f8e756688a0326a' \
 -H 'locale: fr_FR' \
 -H 'Content-Type: text/plain' \
 --data-raw "$(fn_payload_auth)" | jq -r .token.value)

}

fn_get_menu () {

fn_payload_bearer()
{
cat <<EOF
authorization: Bearer $AUTH_TOKEN
EOF
}


# Now get the menu .. i'm hungry !
 menu_jour=$(curl -s "https://apim-production.so-happy.fr/api-app/clients/430/zones-restauration/109/restaurant-menus/?begin_date=$TODAY&shop_id=585d9cc9-390b-431a-b90b-e15fa53c64c9" \
 -H 'Accept: application/json' \
 -H "$(fn_payload_bearer)" \
 -H 'locale: fr_FR' \
 -H 'ocp-apim-subscription-key: 7d777a5c9c7a4def8f8e756688a0326a' \
 -H 'univers_code: CONSOMMATEUR' \
 | jq '[.[] | {date, menus: [.menus[].categories[] | select(.code == "ENTREE" or .code == "PLAT" or .code == "GARNITURE" or .code == "DESSERT") | {category: .label, labels: [.products[].commercial_label]}]}]')
} 


fn_google_cards () {

# Transformation en card Google Chat avec un template
output_json=$(echo $menu_jour | jq -r -c '
  {
    cards: [
      {
        header: {
          title: " 🍽️ Menu du Jour",
          subtitle: (.[0].date | split("T")[0]),
        },
        sections: [
          {
            widgets: [
              {
                textParagraph: {
                  text: "<b>🥗 Entrées :</b>"
                }
              },
              {
                textParagraph: {
                  text: (.[0].menus[0].labels | join("\n ")) 
                }
              },
              {
                textParagraph: {
                  text: "<b>🍲 Plats :</b>"
                }
              },
              {
                textParagraph: {
                  text: (.[0].menus[1].labels | join("\n "))
                }
              },
              {
                textParagraph: {
                  text: "<b>🍛 Garnitures :</b>"
                }
              },
              {
                textParagraph: {
                  text: (.[0].menus[2].labels | join("\n "))
                }
              },
              {
                textParagraph: {
                  text: "<b>🍰 Desserts :</b>"
                }
              },
              {
                textParagraph: {
                  text: (.[0].menus[3].labels | join("\n "))
                }
              }
            ]
          }
        ]
      }
    ]
  }
')

}

fn_google_chat () {

# Envoyer la cards via curl au salon Gchat
curl -X POST -H "Content-Type: application/json; charset=UTF-8" -d "$output_json" "$WEBHOOK_URL"

}


fn_auth
fn_get_menu
fn_google_cards
fn_google_chat

# echo $output_json | jq .
