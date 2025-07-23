#!/bin/bash

EMAIL=$1
PASSWD=$2
WEBHOOK_URL=$3
TODAY=$(date +"%Y-%m-%d")

fn_auth () {

# Get Bearer Token from SoHappy APIM API
AUTH_TOKEN=$(curl -s 'https://apim-production.so-happy.fr/api-app/tokens' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'app_version: 6.55.19' \
  -H 'Ocp-Apim-Subscription-Key: 7d777a5c9c7a4def8f8e756688a0326a' \
  -H 'locale: fr_FR' \
  -H 'Content-Type: text/plain' \
  --data "{\"mail\":\"$EMAIL\",\"password\":\"$PASSWD\"}" | jq -r .token.value)

# echo $AUTH_TOKEN

}

fn_get_menu () {

# Now get the menu .. i'm hungry !
 menu_jour=$(curl -s "https://apim-production.so-happy.fr/api-app/clients/430/zones-restauration/109/restaurant-menus/?begin_date=$TODAY&shop_id=585d9cc9-390b-431a-b90b-e15fa53c64c9" \
 -H 'Accept: application/json' \
 -H "authorization: Bearer $AUTH_TOKEN" \
 -H 'locale: fr_FR' \
 -H 'ocp-apim-subscription-key: 7d777a5c9c7a4def8f8e756688a0326a' \
 -H 'univers_code: CONSOMMATEUR' \
 -H 'verbose: true' \
 | jq '[.[] | {date, menus: [.menus[].categories[] | select(.code == "ENTREE" or .code == "PLAT" or .code == "GARNITURE" or .code == "DESSERT"  or .code == "DESSERT_BAR") | {category: .code, labels: [.products[] | {commercial_label, price_incl_vat, ecoscore}]}]}]'
 )

# Arrondi les prix à x2 chiffres après la virgule.
menu_jour=$(echo $menu_jour | jq '.[0].menus[].labels[] |= (.price_incl_vat |= (. * 100 | round / 100))')

# echo $menu_jour | jq .

} 

fn_google_card () {
# Transformation en card Google Chat avec un template
output_json=$(echo "$menu_jour" | jq -r -c --arg factory_iaas_url "https://u-iris.atlassian.net/wiki/spaces/FIC/overview?homepageId=77103109" '
{
  "cardsV2": [
    {
      "cardId": "menu-card",
      "card": {
        "header": {
          "title": "🍽️ Menu du Jour",
          "subtitle": (.[0].date | split("T")[0])
        },
        "sections": [
          {
            "widgets": [
              {
                "textParagraph": {
                  "text": "🥗 <u>Entrées :</u>"
                }
              },
              {
                "textParagraph": {
                  "text": (.[0].menus[] | select(.category == "ENTREE") | .labels | map("• \(.commercial_label) : <b>\(.price_incl_vat) €</b>") | join("<br>"))
                }
              },
              {
                "textParagraph": {
                  "text": "🍲 <u>Plats :</u>"
                }
              },
              {
                "textParagraph": {
                  "text": (.[0].menus[] | select(.category == "PLAT") | .labels | map("• \(.commercial_label) : <b>\(.price_incl_vat) €</b>") | join("<br>"))
                }
              },
              {
                "textParagraph": {
                  "text": "🍛 <u>Garnitures :</u>"
                }
              },
              {
                "textParagraph": {
                  "text": (.[0].menus[] | select(.category == "GARNITURE") | .labels | map("• \(.commercial_label) : <b>\(.price_incl_vat) €</b>") | join("<br>"))
                }
              },
              {
                "textParagraph": {
                  "text": "🍰 <u>Desserts :</u>"
                }
              },
              {
                "textParagraph": {
                  "text": (.[0].menus[] | select(.category == "DESSERT") | .labels | map("• \(.commercial_label) : <b>\(.price_incl_vat) €</b>") | join("<br>"))
                }
              },
              {
                "textParagraph": {
                  "text": "🍏 <u>Desserts Bar :</u>"
                }
              },
              {
                "textParagraph": {
                  "text": (.[0].menus[] | select(.category == "DESSERT_BAR") | .labels | map("• \(.commercial_label) : <b>\(.price_incl_vat) €</b>") | join("<br>"))
                }
              }
            ]
          },
          {
            "widgets": [
              {
                "decoratedText": {
                  "icon": {
                    "knownIcon": "RESTAURANT_ICON"
                  },
                  "bottomLabel": "La <a href=\"https://u-iris.atlassian.net/wiki/spaces/FIC/overview?homepageId=77103109\">Factory Iaas</a> vous souhaite un bon appétit. 👨‍🍳"
                }
              }
            ]
          }
        ]
      }
    }
  ]
}')




# echo $output_json | jq .

}

fn_google_chat () {

# Envoyer la cards via curl au salon Gchat
curl -X POST -H 'Content-Type: application/json' -d "$output_json" "$WEBHOOK_URL"


}

fn_auth
fn_get_menu
fn_google_card
fn_google_chat
