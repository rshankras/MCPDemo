#!/bin/bash

# Display MCP server paths
node get-paths.js

echo "Choose which MCP server to run:"
echo "1) Documentation Server"
echo "2) Database Server"
echo "3) Exit"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
  1)
    echo "Starting Documentation Server..."
    echo "Press Ctrl+C to stop the server."
    echo ""
    node server.js
    ;;
  2)
    echo "Starting Database Server..."
    echo "Press Ctrl+C to stop the server."
    echo ""
    node database-server.js
    ;;
  3)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac 