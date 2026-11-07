class_name MarketListingSchema
extends RefCounted
## Schema contract and serialization helpers for multiplayer market listings in "Tide & Hook".
## Prepares data formatting for future P2P and backend server trade boards.
##
## Schema Structure:
## {
##   "version": "1.0",
##   "listing_id": String,
##   "seller_id": String,
##   "item_id": String,
##   "item_data": {
##     "species_id": String,
##     "display_name": String,
##     "weight": float,
##     "value": int,
##     "texture_path": String
##   },
##   "price": int,
##   "currency": "sea_coins",
##   "listing_timestamp": int
## }

const SCHEMA_VERSION: String = "1.0"
const DEFAULT_CURRENCY: String = "sea_coins"

const REQUIRED_KEYS: Array[String] = [
	"listing_id",
	"seller_id",
	"item_id",
	"item_data",
	"price",
	"listing_timestamp"
]

const REQUIRED_ITEM_DATA_KEYS: Array[String] = [
	"species_id",
	"display_name",
	"weight",
	"value"
]


## Creates a compliant market listing dictionary from given item data.
static func format_listing(seller_id: String, item_data: Dictionary, price: int) -> Dictionary:
	var species_id: String = item_data.get("species_id", item_data.get("id", "unknown_fish"))
	var now: int = int(Time.get_unix_time_from_system())
	var listing_id: String = "list_%d_%d" % [now, randi() % 100000]

	var formatted_item: Dictionary = {
		"species_id": str(species_id),
		"display_name": str(item_data.get("display_name", item_data.get("name", "Fish"))),
		"weight": float(item_data.get("weight", 1.0)),
		"value": int(item_data.get("value", price)),
		"texture_path": str(item_data.get("texture_path", ""))
	}

	return {
		"version": SCHEMA_VERSION,
		"listing_id": listing_id,
		"seller_id": seller_id,
		"item_id": species_id,
		"item_data": formatted_item,
		"price": maxi(1, price),
		"currency": DEFAULT_CURRENCY,
		"listing_timestamp": now
	}


## Validates whether a dictionary conforms to the required market listing contract.
static func validate(listing: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not listing.has(key):
			push_warning("MarketListingSchema: Missing key '%s'" % key)
			return false

	if not (listing["seller_id"] is String and not listing["seller_id"].is_empty()):
		return false
	if not (listing["item_id"] is String and not listing["item_id"].is_empty()):
		return false
	if not (listing["price"] is int and listing["price"] > 0):
		return false
	if not (listing["listing_timestamp"] is int and listing["listing_timestamp"] > 0):
		return false

	var item_data = listing.get("item_data")
	if not (item_data is Dictionary):
		return false

	for sub_key in REQUIRED_ITEM_DATA_KEYS:
		if not item_data.has(sub_key):
			push_warning("MarketListingSchema: item_data missing key '%s'" % sub_key)
			return false

	return true


## Serializes a valid listing dictionary to a JSON string.
static func to_json(listing: Dictionary) -> String:
	if not validate(listing):
		push_error("MarketListingSchema: Invalid listing cannot be serialized.")
		return ""
	return JSON.stringify(listing)


## Deserializes a JSON string into a validated listing dictionary.
static func from_json(json_text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_error("MarketListingSchema: Failed to parse JSON (%s)" % json.get_error_message())
		return {}

	var dict = json.get_data()
	if not (dict is Dictionary) or not validate(dict):
		push_error("MarketListingSchema: Parsed JSON does not conform to listing schema.")
		return {}

	return dict


## Returns an empty template dictionary illustrating the schema structure.
static func get_schema_template() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"listing_id": "list_1700000000_12345",
		"seller_id": "player_angler_01",
		"item_id": "clownfish",
		"item_data": {
			"species_id": "clownfish",
			"display_name": "Trophy Clownfish",
			"weight": 0.45,
			"value": 15,
			"texture_path": "res://sprites/fish/fish-clownfish.png"
		},
		"price": 20,
		"currency": DEFAULT_CURRENCY,
		"listing_timestamp": 1700000000
	}

