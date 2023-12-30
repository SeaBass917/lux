typedef Predicate = bool Function(dynamic a);

bool any(Iterable iterable, Predicate predicate) {
  for (var ele in iterable) {
    if (predicate(ele)) return true;
  }
  return false;
}

bool all(Iterable iterable, Predicate predicate) {
  for (var ele in iterable) {
    if (!predicate(ele)) return false;
  }
  return true;
}

void forEach(Iterable iterable, Function(dynamic) func) {
  for (var ele in iterable) {
    func(ele);
  }
}
