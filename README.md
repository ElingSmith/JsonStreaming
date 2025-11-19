# JsonStreaming

[![NuGet](https://img.shields.io/nuget/v/JsonStreaming.svg)](https://www.nuget.org/packages/JsonStreaming/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

JsonStreaming provides automatic parameter binding for ASP.NET Core Minimal APIs that eliminates the need to manually parse HTTP request bodies with arrays into IAsyncEnumerable
sequences,
whilst also still letting the user control the binding for advanced use cases.

## Installation

```bash
dotnet add package JsonStreaming
```

## Quick Start

JsonStreaming supports two usage modes:

1. **With Source Generation** (recommended for Native AOT and best performance)
2. **Without Source Generation** (simpler setup, uses reflection-based deserialization)

### Option A: With Source Generation (Recommended)

#### 1. Define your model with Source Generation

```csharp
public record MyDto(int Id, string Name, decimal Value);

[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(MyDto))]
public partial class MyJsonContext : JsonSerializerContext
{
}
```

#### 2. Register in DI (Choose One Method)

**Add a single type**

```csharp
builder.Services.AddJsonStreamType(MyJsonContext.Default.MyDto);
```

**Add multiple types using a Fluent API**

```csharp
builder.Services.AddJsonStreamTypes()
    .Add(MyJsonContext.Default.MyDto)
    .Add(MyJsonContext.Default.OtherDto)
    .Build();
```

**Add to the registry directly**

```csharp
builder.Services.AddJsonStreamTypeInfo(registry =>
{
    registry.RegisterTypeInfo(MyJsonContext.Default.MyDto);
});
```

**Auto-Discovery (Uses reflection)**

```csharp
builder.Services.AddJsonStreamContext<MyJsonContext>();
```

#### 3. Use in Minimal API Endpoints

```csharp
app.MapPost("/process", async (JsonStream<MyDto> items) =>
{
    await foreach (var item in items)
    {
        // Process each item as it arrives from the request
        Console.WriteLine($"Processing: {item.Name}");
    }
    return Results.Ok();
});
```

### Option B: Without Source Generation (Simplest setup)

If you don't need Native AOT support, you can use JsonStreaming without source generation. The library will automatically fall back to reflection-based deserialization.

**Note:** `JsonStream<T>` automatically uses `JsonSerializerDefaults.Web` when no `JsonSerializerOptions` are registered, which provides:

- ✅ Case-insensitive property matching
- ✅ camelCase property names by default
- ✅ Works with standard web APIs out of the box

#### 1. Define your model (No Source Generation required)

```csharp
public record MyDto(int Id, string Name, decimal Value);
```

#### 2. Optional: Configure JsonSerializerOptions

```csharp
// Only register custom JsonSerializerOptions if you need different settings
// Otherwise, JsonSerializerDefaults.Web is used automatically for JsonStream<T>
builder.Services.AddSingleton(new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
});
```

#### 3. Use in Minimal API Endpoints

```csharp
// Automatically handles camelCase JSON from web clients
// No DI registration needed!
app.MapPost("/process", async (JsonStream<MyDto> items) =>
{
    await foreach (var item in items)
    {
        // Process each item as it arrives from the request
        Console.WriteLine($"Processing: {item.Name}");
    }
    return Results.Ok();
});
```

Example request body:

```json
[
    {
        "id": 1,
        "name": "First Item",
        "value": 10.5
    },
    {
        "id": 2,
        "name": "Second Item",
        "value": 20.5
    }
]
```

### Direct PipeReader usage without any binding

#### With Source Generation

```csharp
var pipe = new Pipe();
// write JSON to the pipe object yourself ...

await foreach (var item in JsonStreamReader.ReadArrayAsync<MyDto>(
    pipe.Reader,
    typeInfo: MyJsonContext.Default.MyDto))
{
    // Process item
}
```

#### Without Source Generation

```csharp
var pipe = new Pipe();
// write JSON to the pipe object yourself ...

// Option 1: No options (case-sensitive by default for JsonStreamReader)
// Note: JsonStream<T> binding uses Web defaults, but direct JsonStreamReader does not
await foreach (var item in JsonStreamReader.ReadArrayAsync<MyDto>(pipe.Reader))
{
    // Process item - requires exact property name casing
}

// Option 2: With custom options (recommended for camelCase JSON)
var options = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
};

await foreach (var item in JsonStreamReader.ReadArrayAsync<MyDto>(
    pipe.Reader,
    options: options))
{
    // Process item - works with camelCase
}
```

## Advanced Usage

### Custom JsonReaderOptions

```csharp
var readerOptions = new JsonReaderOptions
{
    CommentHandling = JsonCommentHandling.Disallow,
    MaxDepth = 64
};

await foreach (var item in JsonStreamReader.ReadArrayAsync<MyDto>(
    pipe.Reader,
    typeInfo: typeInfo,
    readerOptions: readerOptions))
{
    // Process item
}
```

### Tuning Buffer Size

For large datasets, you can adjust the initial buffer size:

```csharp
await foreach (var item in JsonStreamReader.ReadArrayAsync<MyDto>(
    pipe.Reader,
    typeInfo: typeInfo,
    initialBufferSize: 128))  // Default is 32
{
    // Process item
}
```

## Performance

The library uses ArrayPool-based buffer management for optimal memory efficiency:

**Benchmark Results (1000 items):**

- Allocated: ~444 KB (96% from objects, 4% from overhead)
- Gen0: 60.5 collections
- Gen1: 50% fewer compared to List-based buffering
- Gen2: Minimal

**Key optimizations:**

- ArrayPool for zero-allocation buffer reuse
- Pre-sized buffers to reduce resizing

## Native AOT compatibility summary

JsonStreaming is compatible with Native AOT when using source-generated JSON:

```xml

<PropertyGroup>
    <PublishAot>true</PublishAot>
</PropertyGroup>
```

**AOT-Compatible registration methods:**

- ✅ `AddJsonStreamType` - No reflection
- ✅ `AddJsonStreamTypes` - No reflection
- ✅ `AddJsonStreamTypeInfo` - No reflection
- ⚠️ `AddJsonStreamContext` - Uses reflection (not AOT-compatible)

**Without Source Generation:**

- ❌ Reflection-based deserialization is **NOT** compatible with Native AOT
- Use source generation for AOT scenarios

## How It Works

1. **Reads from PipeReader** - Efficient streaming I/O using System.IO.Pipelines
2. **Parses JSON incrementally** - Uses Utf8JsonReader for fast parsing
3. **Buffers per chunk** - Collects items from each pipeline buffer read
4. **Yields items** - Returns items asynchronously via `IAsyncEnumerable<T>`
5. **Reuses buffers** - Returns ArrayPool buffers for zero-allocation streaming

## Usage Recommendations

Below you can find the general use cases on when to use each approach. This is only a general guideline, and you should always test your own scenarios to determine the best
approach for your application.

| Scenario                  | Recommended Approach                                       |
|---------------------------|------------------------------------------------------------|
| Native AOT applications   | Use source generation with explicit registration methods   |
| High-performance services | Use source generation for best performance                 |
| Rapid prototyping         | Use without source generation for simpler setup            |
| Legacy codebases          | Use without source generation with `JsonSerializerOptions` |
| Mixed AOT/non-AOT         | Use source generation for consistency                      |

## Requirements

- .NET 8.0, 9.0, or 10.0
- ASP.NET Core (for JsonStream parameter binding)
