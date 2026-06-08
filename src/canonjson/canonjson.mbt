/// Canonicalizes a JSON document into a compact deterministic payload for
/// digest calculation. Objects are rendered with lexicographically sorted keys;
/// RFC 8785 number formatting is still a documented future hardening item.
pub fn canonicalize(input : String) -> String raise @json.ParseError {
  let value = @json.parse(input)
  render(value)
}

/// Returns `None` instead of raising when the input is not valid JSON.
pub fn canonicalize_or_none(input : String) -> String? {
  try {
    Some(canonicalize(input))
  } catch {
    (_ : @json.ParseError) => None
  }
}

/// Checks whether two JSON payloads have the same canonical representation.
pub fn same_canonical_payload(left : String, right : String) -> Bool {
  match (canonicalize_or_none(left), canonicalize_or_none(right)) {
    (Some(a), Some(b)) => a == b
    _ => false
  }
}

fn render(value : Json) -> String {
  match value {
    Object(obj) => {
      let entries = obj.iter().to_array()
      entries.sort_by(fn(left, right) {
        let (left_key, _) = left
        let (right_key, _) = right
        left_key.compare(right_key)
      })
      render_object_entries(entries)
    }
    Array(items) => render_array(items)
    _ => value.stringify()
  }
}

fn render_object_entries(entries : Array[(String, Json)]) -> String {
  let mut output = "{"
  for index in 0..<entries.length() {
    if index > 0 {
      output = output + ","
    }
    let (key, value) = entries[index]
    output = output + Json::string(key).stringify() + ":" + render(value)
  }
  output + "}"
}

fn render_array(items : Array[Json]) -> String {
  let mut output = "["
  for index in 0..<items.length() {
    if index > 0 {
      output = output + ","
    }
    output = output + render(items[index])
  }
  output + "]"
}
