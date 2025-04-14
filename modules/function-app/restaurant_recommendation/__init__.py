import azure.functions as func
import json
import datetime
import logging
import os
from azure.cosmos import CosmosClient, exceptions

# Initialize Cosmos DB client
cosmos_endpoint = os.environ["COSMOS_ENDPOINT"]
cosmos_key = os.environ["COSMOS_KEY"]
database_name = os.environ["COSMOS_DATABASE"]
container_name = os.environ["COSMOS_CONTAINER"]

# Initialize the Cosmos client
client = CosmosClient(cosmos_endpoint, cosmos_key)
database = client.get_database_client(database_name)
container = database.get_container_client(container_name)

def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    logging.info(f"Restaurant recommendation request received. RequestID: {context.invocation_id}")
    
    try:
        # Get request data
        req_body = req.get_json() if req.get_body() else {}
        query_description = req_body.get('description', '')
        
        # Log the request (excluding any potentially sensitive data)
        logging.info(f"Request type: Restaurant recommendation. Request ID: {context.invocation_id}")
        
        # Parse the request criteria
        criteria = parse_request_criteria(query_description)
        
        # Get current time for "open now" check
        current_time = datetime.datetime.now().strftime("%H:%M")
        
        # Query Cosmos DB based on criteria
        restaurant = find_restaurant(criteria, current_time)
        
        if restaurant:
            # Return the recommendation
            result = {
                "restaurantRecommendation": restaurant
            }
            logging.info(f"Restaurant recommendation provided successfully. Request ID: {context.invocation_id}")
            return func.HttpResponse(json.dumps(result), mimetype="application/json")
        else:
            # No restaurant found matching criteria
            logging.info(f"No restaurant found matching criteria. Request ID: {context.invocation_id}")
            return func.HttpResponse(
                json.dumps({"message": "No restaurants matching the provided criteria"}),
                mimetype="application/json",
                status_code=404
            )
            
    except Exception as e:
        # Log error but don't expose details to client
        error_id = context.invocation_id
        logging.error(f"Error processing request. Error ID: {error_id}. Details: {str(e)}")
        return func.HttpResponse(
            json.dumps({"message": f"Error processing request. Reference ID: {error_id}"}),
            mimetype="application/json",
            status_code=500
        )

def parse_request_criteria(description):
    """Parse the natural language request into criteria"""
    criteria = {
        "style": None,
        "vegetarian": None,
        "delivery": None,
        "open_now": False
    }
    
    # Convert to lowercase for easier matching
    description = description.lower()
    
    # Check for cuisine styles
    cuisine_styles = ["italian", "french", "korean", "japanese", "mexican", "indian", "chinese"]
    for style in cuisine_styles:
        if style in description:
            criteria["style"] = style.capitalize()
            break
    
    # Check for vegetarian option
    if "vegetarian" in description:
        criteria["vegetarian"] = True
    
    # Check for delivery option
    if "delivery" in description:
        criteria["delivery"] = True
    
    # Check for "open now" request
    if "open now" in description:
        criteria["open_now"] = True
    
    return criteria

def find_restaurant(criteria, current_time):
    """Query Cosmos DB for restaurants matching criteria"""
    query = "SELECT * FROM c WHERE 1=1"
    parameters = []
    param_index = 0
    
    # Add style filter if specified
    if criteria["style"]:
        param_name = f"@p{param_index}"
        query += f" AND c.style = {param_name}"
        parameters.append({"name": param_name, "value": criteria["style"]})
        param_index += 1
    
    # Add vegetarian filter if specified
    if criteria["vegetarian"] is not None:
        param_name = f"@p{param_index}"
        query += f" AND c.vegetarian = {param_name}"
        parameters.append({"name": param_name, "value": criteria["vegetarian"]})
        param_index += 1
    
    # Add delivery filter if specified
    if criteria["delivery"] is not None:
        param_name = f"@p{param_index}"
        query += f" AND c.deliveryAvailable = {param_name}"
        parameters.append({"name": param_name, "value": criteria["delivery"]})
        param_index += 1
    
    # Add "open now" filter if specified
    if criteria["open_now"]:
        param_name = f"@p{param_index}"
        query += f" AND {param_name} BETWEEN c.openHour AND c.closeHour"
        parameters.append({"name": param_name, "value": current_time})
        param_index += 1
    
    # Execute the query
    logging.info(f"Executing query: {query} with parameters: {parameters}")
    
    try:
        items = list(container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        ))
        
        # Return the first matching restaurant
        return items[0] if items else None
    
    except exceptions.CosmosHttpResponseError as e:
        logging.error(f"Cosmos DB query error: {str(e)}")
        return None