# MCP Demo App

This demo app showcases integration with the Model Context Protocol (MCP), allowing an LLM assistant to access external data sources.

## Project Structure

- **MCPDemo/** - Swift app code
- **MCPServer/** - Node.js MCP server implementations

## Setting Up the MCP Servers

The app needs to connect to the MCP servers to access the demo document resources and database queries. There are two servers:

1. **Documentation Server** (port 3000) - Provides access to Markdown documentation
2. **Database Server** (port 3001) - Provides access to a SQLite database with employee records

### Starting the Servers

Open two terminal windows and run the following commands:

**Documentation Server (Terminal 1):**
```bash
cd MCPServer
node server.js
```

**Database Server (Terminal 2):**
```bash
cd MCPServer
node database-server.js
```

Both servers will start in HTTP mode and listen on their respective ports (3000 and 3001).

## Using the App

1. Launch the MCPDemo app
2. Click on the network icon in the top right
3. Connect to both servers using the preset buttons
4. Once connected, you can use the chat interface to ask questions that require access to the external data sources

## Troubleshooting

If you encounter connection errors:

1. **Port conflicts** - Make sure no other applications are using ports 3000 and 3001
   - You can check if ports are in use with: `lsof -i:3000,3001`
   - If servers are already running, you'll see "EADDRINUSE" errors
   - No need to restart servers if they're already running

2. **Servers not running** - Check that both Node.js servers are running in the terminal
   - Look for messages like "Documentation MCP Server running at http://localhost:3000/"
   - If you see no output or errors, try starting the servers

3. **Path issues** - If running from Xcode, ensure the working directory is set correctly
   - The app looks for servers at http://localhost:3000 and http://localhost:3001
   - Make sure paths to JavaScript files are correct

4. **API mismatches** - MCP protocol version differences
   - If you see errors about methods like "resources/list", update the server files
   - The app has fallback mechanisms for common API issues

5. **Sandbox restrictions** - Mac app sandbox may limit file access
   - When running as a sandboxed app, file paths may need adjustment
   - Consider running with reduced security for testing

## Checking Server Status

To verify servers are running correctly, try accessing them directly:

```bash
curl -X POST http://localhost:3000 -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"resources/list","params":{},"id":"test"}'
```

This should return a list of resources in JSON format.

## Development Notes

- The app uses the MCP Swift SDK version 0.8.2
- Connection timeout is set to 10 seconds
- The HTTP transport is configured with streaming disabled to avoid type mismatches 