import logging
import json
import azure.functions as func

# Sample restaurant data - in a real application, this would come from a database
restaurants = [
    {
        "id": 1,
        "name": "Pasta Paradise",
        "cuisine": "Italian",
        "address": "123 Main Street",
        "rating": 4.5,
        "signature_dish": "Fettuccine Alfredo",
        "hours": "11:00 AM - 10:00 PM",
        "price_range": "$$"
    },
    {
        "id": 2,
        "name": "Sushi Spot",
        "cuisine": "Japanese",
        "address": "456 Ocean Avenue",
        "rating": 4.8,
        "signature_dish": "Dragon Roll",
        "hours": "12:00 PM - 11:00 PM",
        "price_range": "$$$"
    }
]

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # Get the route parameters and query parameters
    route = req.route_params.get('route')
    restaurant_id = req.params.get('id')
    
    # Default response is the list of all restaurants
    if not route or route == "list":
        return func.HttpResponse(
            json.dumps({"restaurants": restaurants}),
            mimetype="application/json",
            status_code=200
        )
    
    # Get details for a specific restaurant
    elif route == "details":
        if not restaurant_id:
            return func.HttpResponse(
                json.dumps({"error": "Please provide a restaurant ID"}),
                mimetype="application/json",
                status_code=400
            )
        
        try:
            # Convert to integer and find the restaurant
            restaurant_id = int(restaurant_id)
            restaurant = next((r for r in restaurants if r["id"] == restaurant_id), None)
            
            if restaurant:
                return func.HttpResponse(
                    json.dumps({"restaurant": restaurant}),
                    mimetype="application/json",
                    status_code=200
                )
            else:
                return func.HttpResponse(
                    json.dumps({"error": f"Restaurant with ID {restaurant_id} not found"}),
                    mimetype="application/json",
                    status_code=404
                )
        except ValueError:
            return func.HttpResponse(
                json.dumps({"error": "Restaurant ID must be a number"}),
                mimetype="application/json",
                status_code=400
            )
    
    # Handle unknown routes
    else:
        return func.HttpResponse(
            json.dumps({"error": f"Unknown route: {route}"}),
            mimetype="application/json",
            status_code=404
        )