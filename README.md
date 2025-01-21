# openapi-arrangement

A Ruby gem intended for use with code generation templates alongside openapi-generate tool from openapi-sourcetools gem. This gem provides functions to arrange schemas in desired order.

Considering the intended usage, openapi-generate provides Gen module referred to below. The code to add ordering when adding tasks is:

```ruby
require 'openapi/arrangement'

# Somewhere in your initialization task generate-method:
Gen.x[:order] = OpenAPIArrangement::Schema.dependencies_first(Gen.doc)
# Or if forward declarations are not an issue for the programming language:
Gen.x[:order] = OpenAPIArrangement::Schema.alphabetical(Gen.doc)
```

Return value is an array of OpenAPIArrangement::Schema::Info class instances.

In ERB template you probably should include the used version in a comment somewhere:

```
<%= OpenAPIArrangement.info %>
```

## License

Copyright © 2024-2025 Ismo Kärkkäinen

Licensed under Universal Permissive License. See LICENSE.txt.
