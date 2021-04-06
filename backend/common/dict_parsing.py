def parse_dict(d: dict, remove: list = None, rename: dict = None, recursive=True):
    """changed 'd' param by removing fields in 'remove' and renaming ones in 'rename'"""
    if remove:
        for r in remove:
            if d.get(r) is None: continue
            d.pop(r)
    if rename:
        for k, v in rename.items():
            if d.get(k) is None: continue
            d[v] = d[k]
            d.pop(k)

    if recursive:
        for k in d.keys():
            if isinstance(d[k], dict):
                parse_dict(d[k], remove, rename, recursive)

    return d


def drop_none(d: dict):
    for k in list(d.keys()):
        if d[k] is None:
            d.pop(k)
    return d
