# Project Memory

- The GDScript brush runtime is intended to be a direct conversion of the working C# brush runtime, not a behavioral rewrite.
- The project still has two C# references:
  - upstream Open Brush C# source,
  - the Godot .NET C# port on another branch.
- For mesh parity work, prefer the Godot .NET C# port as the immediate oracle for C#-to-GDScript conversion parity, and use upstream Open Brush C# as the source-of-truth reference when investigating C# behavior.
- Do not reinvent mesh behavior with hand-derived expectations when a same-input C# vs GDScript mesh comparison can be used instead.
