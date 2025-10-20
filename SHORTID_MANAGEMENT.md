# Client Management with ShortID Support

## Overview
The client management system now supports automatic ShortID management for Reality protocol connections.

## How ShortID Management Works

### Adding Clients
- When adding a new client, a new ShortID is automatically generated
- The ShortID is appended to the `shortIds` array in the Reality configuration
- Each client has a corresponding ShortID at the same index position

### Listing Clients  
- Shows client name, UUID, and corresponding ShortID
- ShortID is determined by client's index position in the array
- If no ShortID exists for a client (array too short), shows "N/A"

### Deleting Clients
- Only removes the client from the `clients` array
- **ShortIDs are NOT removed** to preserve index correspondence
- This prevents breaking ShortID assignments for remaining clients

### Share Link Generation
- Uses the ShortID that corresponds to the client's original index
- Ensures consistent connection parameters for each client

## Index Correspondence
```
clients[0] ← → shortIds[0]  (client1)
clients[1] ← → shortIds[1]  (client2) 
clients[2] ← → shortIds[2]  (client3)
```

If client2 is deleted:
```
clients[0] ← → shortIds[0]  (client1)
clients[1] ← → shortIds[2]  (client3, now at index 1 but uses shortIds[2])
               shortIds[1]  (preserved but unused)
```

## Commands
- `./client.sh list` - List all clients with their ShortIDs
- `./client.sh add "name"` - Add new client with auto-generated ShortID  
- `./client.sh delete N` - Delete client N (ShortIDs preserved)
- `./client.sh share N` - Generate share link for client N with correct ShortID

## Notes
- This approach ensures stable connections even after client deletions
- ShortID arrays may grow over time but won't break existing clients
- Index-based mapping provides predictable behavior