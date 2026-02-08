# LiveKit RedisRouter - Multi-Node Architecture

## Overview
RedisRouter enables LiveKit to run across multiple servers (nodes) by using Redis as a coordination layer.

## Key Concepts

### 1. **Redis Keys Used**
- `nodes` (hash) - Stores all active LiveKit server nodes
  - Key: nodeID → Value: Node proto (state, stats, capabilities)
- `room_node_map` (hash) - Maps rooms to the nodes hosting them
  - Key: roomName → Value: nodeID

### 2. **How It Works**

#### Node Registration
When a LiveKit server starts:
```
1. Server creates a Node object with its ID, IP, stats
2. Serializes to protobuf
3. Stores in Redis: HSET nodes <nodeID> <nodeData>
```

**Look for logs:**
```
[REDIS_ROUTER] Registering node in Redis
[REDIS_ROUTER] Node registered successfully in Redis
```

#### Room Assignment
When a room is created:
```
1. System selects a node (based on load, region, etc.)
2. Maps room to node: HSET room_node_map <roomName> <nodeID>
3. Room only exists on that specific node
```

**Look for logs:**
```
[REDIS_ROUTER] Mapping room to node in Redis
[REDIS_ROUTER] Room-to-node mapping saved in Redis
```

#### Participant Joining
When a participant joins a room:
```
1. System looks up room: HGET room_node_map <roomName>
2. Gets the nodeID where room exists
3. Routes participant to that specific node
4. WebSocket connection goes to correct server
```

**Look for logs:**
```
[REDIS_ROUTER] Starting participant signal routing
[REDIS_ROUTER] Looking up node for room in Redis
[REDIS_ROUTER] Found node for room
[REDIS_ROUTER] Routing participant to node
```

#### Multi-Node Discovery
Any node can query all available nodes:
```
1. HVALS nodes - gets all node data
2. Deserializes each node
3. Returns list of active servers
```

**Look for logs:**
```
[REDIS_ROUTER] Listing all nodes from Redis
[REDIS_ROUTER] Found nodes in Redis (nodeCount: X)
[REDIS_ROUTER] Node details (for each node)
```

### 3. **Load Balancing**
- Each node publishes its stats (CPU, memory, room count, client count)
- When creating a room, selector picks the best node based on:
  - Current load
  - Geographic region
  - Availability state

### 4. **High Availability**
- **Keepalive Worker**: Each node sends periodic pings via Redis pub/sub
- **Stats Worker**: Updates node statistics regularly
- Dead nodes are removed automatically

### 5. **Example Flow: Multi-Node Setup**

```
Server 1 (US-East)    Redis           Server 2 (US-West)
     |                  |                    |
     |-- Register ----->|<---- Register -----|
     |   (nodeID: N1)   |     (nodeID: N2)   |
     |                  |                    |
User creates "room-A"   |                    |
     |                  |                    |
     |-- SetNodeForRoom |                    |
     |   room-A → N1    |                    |
     |                  |                    |
User joins "room-A"     |                    |
     |                  |                    |
     |-- GetNodeForRoom |                    |
     |   room-A → N1    |                    |
     |                  |                    |
     |<- Connect to N1  |                    |
     |                  |                    |
User creates "room-B"   |                    |
     |                  |                    |
     |                  |-- SetNodeForRoom --|
     |                  |   room-B → N2      |
     |                  |                    |
User joins "room-B"     |                    |
     |                  |                    |
     |-- GetNodeForRoom |                    |
     |   room-B → N2    |                    |
     |                  |                    |
     |                  |--- Connect to N2 ->|
```

## How to Test Multi-Node Locally

### 1. Start Redis
```bash
docker run -d -p 6379:6379 redis:latest
```

### 2. Configure LiveKit for Redis
Create `config.yaml`:
```yaml
redis:
  address: localhost:6379

# Node 1 config
port: 7880
rtc:
  port_range_start: 7882
  port_range_end: 7900

# For Node 2, use different ports
# port: 7980
# rtc:
#   port_range_start: 7982
#   port_range_end: 8000
```

### 3. Run Multiple Nodes
```bash
# Terminal 1 - Node 1
./bin/livekit-server --config config.yaml --node-id node1

# Terminal 2 - Node 2 (different ports)
./bin/livekit-server --config config2.yaml --node-id node2
```

## Filtering Logs

To see only Redis router logs:
```bash
# While server is running
grep "\[REDIS_ROUTER\]" livekit.log

# Live tail
tail -f livekit.log | grep "\[REDIS_ROUTER\]"
```

## What to Watch For

1. **Node Registration**: Each server registers itself
2. **Room Creation**: See which node gets assigned
3. **Participant Routing**: Watch how clients are directed to correct node
4. **Load Distribution**: See how rooms spread across nodes
5. **Node Stats**: Check updates showing room/client counts

## Common Patterns

### Single Node (Development)
- Uses `LocalRouter` instead of `RedisRouter`
- All rooms on one server
- No Redis needed

### Multi Node (Production)
- Uses `RedisRouter`
- Rooms distributed across servers
- Redis coordinates everything
- Clients connect to correct server automatically
