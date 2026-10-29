"""Reviewed synthetic scenarios for #585, #586, #589 and #598 only."""
VISUALS = tuple(
    f'admin-search-{scale}-{inset}.png'
    for scale in (1.0, 1.3, 2.0) for inset in (0.0, 300.0)
) + ('search-scope-48dp.png', 'revoked-image-pending-false.png',
     'revoked-image-pending-true.png', 'dm-attachment-send-jpeg.png',
     'dm-attachment-send-gif.png')
