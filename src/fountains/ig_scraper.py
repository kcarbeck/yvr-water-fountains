import instaloader
import re
import pandas as pd

L = instaloader.Instaloader()
profile = instaloader.Profile.from_username(L.context, 'yvrwaterfountains')

rows = []
for post in profile.get_posts():
    caption = post.caption or ""
    # Look for a hashtag like #f<ID> in the caption
    match = re.search(r'#f([A-Za-z0-9]+)', caption)
    if match:
        fountain_id = match.group(1)
        rows.append({
            'id': fountain_id,
            'ig_post_url': f"https://www.instagram.com/p/{post.shortcode}/",
            'rating': '',  # Manual entry
            'flow_emoji': '',  # Manual entry
            'temp_emoji': '',  # Manual entry
            'caption': caption,
            'photo_url': post.url,
            'visited': '',  # Manual entry
            'visit_date': post.date_utc.strftime('%Y-%m-%d'),
        })

df = pd.DataFrame(rows)
df.to_csv('data/ratings.csv', index=False)
print('✔ wrote data/ratings.csv') 