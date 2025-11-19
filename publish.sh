#!/bin/bash

# JsonStreaming NuGet Publishing Script
# This script builds, tests, and optionally publishes the package to NuGet

set -e  # Exit on error

echo "🚀 JsonStreaming Package Publisher"
echo "=================================="
echo ""

# Parse arguments
PUBLISH=false
API_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --publish)
      PUBLISH=true
      shift
      ;;
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    --help)
      echo "Usage: ./publish.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --publish         Publish to NuGet (default: false)"
      echo "  --api-key KEY     NuGet API key (required if --publish is set)"
      echo "  --help            Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./publish.sh                           # Build and pack only"
      echo "  ./publish.sh --publish --api-key KEY   # Build, pack, and publish"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate arguments
if [ "$PUBLISH" = true ] && [ -z "$API_KEY" ]; then
  echo "❌ Error: --api-key is required when --publish is specified"
  exit 1
fi

# Step 1: Clean
echo "🧹 Cleaning previous builds..."
dotnet clean

# Step 2: Restore
echo "📦 Restoring dependencies..."
dotnet restore

# Step 3: Build
echo "🔨 Building project..."
dotnet build -c Release --no-restore

# Step 4: Test
echo "🧪 Running tests..."
dotnet test -c Release --no-build --verbosity normal

# Step 5: Pack
echo "📦 Creating NuGet package..."
rm -rf ./nupkg
dotnet pack JsonStreaming/JsonStreaming.csproj -c Release --no-build -o ./nupkg

# List created packages
echo ""
echo "✅ Package created successfully:"
ls -lh ./nupkg/*.nupkg

# Step 6: Publish (if requested)
if [ "$PUBLISH" = true ]; then
  echo ""
  echo "📤 Publishing to NuGet..."
  dotnet nuget push ./nupkg/*.nupkg \
    --api-key "$API_KEY" \
    --source https://api.nuget.org/v3/index.json \
    --skip-duplicate
  
  echo ""
  echo "✅ Package published successfully!"
  echo "🔗 View at: https://www.nuget.org/packages/JsonStreaming"
else
  echo ""
  echo "✅ Package ready for publishing!"
  echo ""
  echo "To publish, run:"
  echo "  ./publish.sh --publish --api-key YOUR_API_KEY"
  echo ""
  echo "Or manually:"
  echo "  dotnet nuget push ./nupkg/*.nupkg --api-key YOUR_API_KEY --source https://api.nuget.org/v3/index.json"
fi

echo ""
echo "🎉 Done!"
