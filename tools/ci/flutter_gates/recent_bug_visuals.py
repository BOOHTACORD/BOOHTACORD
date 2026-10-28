"""Reviewed synthetic scenarios for #585, #586 and #589 only."""
VISUALS = tuple(
    f'admin-search-{scale}-{inset}.png'
    for scale in (1.0, 1.3, 2.0) for inset in (0.0, 300.0)
) + ('search-scope-48dp.png', 'revoked-image-pending-false.png',
     'revoked-image-pending-true.png')
