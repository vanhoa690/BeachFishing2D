class_name MultiplayerMarketStub
extends RefCounted
## Multiplayer Global Market Data Contract & Service Stub
## Designed for future P2P / WebSocket backend integration in Tide & Hook.
##
## Listing Contract Schema:
## {
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
##   "listing_timestamp": int
## }

signal listing_created(listing: Dictionary)
signal listing_purchased(listing_id: String, buyer_id: String)
signal listing_cancelled(listing_id: String)
signal market_refreshed(listings: Array)

const REQUIRED_SCHEMA_KEYS: Array[String] = [
	"seller_id",
	"item_id",
	"item_data",
	"price",
	"listing_timestamp"
]

var _active_listings: Array[Dictionary] = []


func _init() -> void:
	# Populate sample community listings for early testing
	generate_mock_community_listings()


## Validates whether a dictionary conforms to the multiplayer market listing contract.
static func validate_listing(listing: Dictionary) -> bool:
	for k in REQUIRED_SCHEMA_KEYS:
		if not listing.has(k):
			push_warning("MultiplayerMarketStub: Missing required key '%s'" % k)
			return false

	if not (listing["seller_id"] is String and not listing["seller_id"].is_empty()):
		return false
	if not (listing["item_id"] is String and not listing["item_id"].is_empty()):
		return false
	if not (listing["item_data"] is Dictionary):
		return false
	if not (listing["price"] is int and listing["price"] > 0):
		return false
	if not (listing["listing_timestamp"] is int and listing["listing_timestamp"] > 0):
		return false

	return true


## Serializes a market listing to a JSON string.
static func serialize_to_json(listing: Dictionary) -> String:
	if not validate_listing(listing):
		push_error("MultiplayerMarketStub: Cannot serialize invalid listing dictionary.")
		return ""
	return JSON.stringify(listing)


## Deserializes a JSON string into a validated market listing dictionary.
static func deserialize_from_json(json_str: String) -> Dictionary:
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		push_error("MultiplayerMarketStub: Failed to parse JSON (%s)" % json.get_error_message())
		return {}

	var data = json.get_data()
	if not (data is Dictionary):
		push_error("MultiplayerMarketStub: Decoded JSON is not a dictionary.")
		return {}

	if not validate_listing(data):
		push_error("MultiplayerMarketStub: Decoded dictionary failed contract validation.")
		return {}

	return data


## Creates a new listing and publishes it to the market board.
func create_listing(seller_id: String, item_data: Dictionary, price: int) -> Dictionary:
	var listing_id: String = "list_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]
	var item_id: String = item_data.get("species_id", "unknown_item_%d" % randi())

	var listing: Dictionary = {
		"listing_id": listing_id,
		"seller_id": seller_id,
		"item_id": item_id,
		"item_data": item_data.duplicate(true),
		"price": price,
		"listing_timestamp": int(Time.get_unix_time_from_system())
	}

	if not validate_listing(listing):
		push_error("MultiplayerMarketStub: Created listing failed schema validation.")
		return {}

	_active_listings.append(listing)
	listing_created.emit(listing)
	market_refreshed.emit(_active_listings)
	return listing


## Retrieves all active listings currently published.
func get_active_listings() -> Array[Dictionary]:
	return _active_listings.duplicate(true)


## Purchases an active listing by id. Returns true on success.
func buy_listing(listing_id: String, buyer_id: String) -> bool:
	for i in range(_active_listings.size()):
		if _active_listings[i].get("listing_id") == listing_id:
			var listing = _active_listings[i]
			_active_listings.remove_at(i)
			listing_purchased.emit(listing_id, buyer_id)
			market_refreshed.emit(_active_listings)
			return true
	return false


## Cancels an active listing owned by seller_id.
func cancel_listing(listing_id: String, seller_id: String) -> bool:
	for i in range(_active_listings.size()):
		var item = _active_listings[i]
		if item.get("listing_id") == listing_id and item.get("seller_id") == seller_id:
			_active_listings.remove_at(i)
			listing_cancelled.emit(listing_id)
			market_refreshed.emit(_active_listings)
			return true
	return false


## Generates mock community listings simulating other online anglers.
func generate_mock_community_listings() -> void:
	_active_listings.clear()
	var mock_sellers := ["Captain_Barnaby", "Salty_Sam", "Marina_Rose", "Shoreline_Pete"]
	var mock_species := [
		{
			"species_id": "clownfish",
			"display_name": "Trophy Clownfish",
			"weight": 1.25,
			"value": 18,
			"texture_path": "res://sprites/fish/fish-clownfish.png"
		},
		{
			"species_id": "red_snapper",
			"display_name": "Giant Red Snapper",
			"weight": 4.10,
			"value": 45,
			"texture_path": "res://sprites/fish/fish-red-snapper.png"
		},
		{
			"species_id": "blue_tang",
			"display_name": "Deep Reef Blue Tang",
			"weight": 2.80,
			"value": 32,
			"texture_path": "res://sprites/fish/fish-blue-tang.png"
		}
	]

	var now := int(Time.get_unix_time_from_system())
	for i in range(mock_species.size()):
		var fish_data = mock_species[i]
		var seller = mock_sellers[i % mock_sellers.size()]
		var price = int(fish_data["value"] * 1.2) # modest player markup

		_active_listings.append({
			"listing_id": "mock_list_%03d" % (i + 1),
			"seller_id": seller,
			"item_id": fish_data["species_id"],
			"item_data": fish_data,
			"price": price,
			"listing_timestamp": now - (i * 300)
		})

