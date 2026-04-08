from firebase_functions import https_fn, scheduler_fn, firestore_fn
from firebase_admin import initialize_app, firestore, storage, messaging
import openpyxl
import requests
from io import BytesIO
from datetime import datetime
import datetime as dt_module
from PIL import Image, ImageDraw, ImageFont, ImageOps
from google.cloud import firestore as google_firestore
import pytz

initialize_app()

def generate_birthday_card(user_data):
    width, height = 1080, 1080
    # Rich Dark Navy Background
    card = Image.new('RGB', (width, height), color=(0, 20, 40))
    draw = ImageDraw.Draw(card)

    try:
        font_lg = ImageFont.truetype("LilitaOne-Regular.ttf", 110)
        font_md = ImageFont.truetype("LilitaOne-Regular.ttf", 85)
        font_sm = ImageFont.truetype("LilitaOne-Regular.ttf", 45)
    except:
        font_lg = font_md = font_sm = ImageFont.load_default()

    # --- THE DESIGN UPGRADE ---
    # Top Left Circle (NSBM Green)
    draw.ellipse([(-200, -200), (450, 450)], fill=(58, 181, 74))
    # Bottom Right Circle (NSBM Blue)
    draw.ellipse([(650, 700), (1300, 1350)], fill=(25, 88, 159))

    # Profile Picture Logic
    try:
        response = requests.get(user_data.get('profile_pic', ''), timeout=10)
        p_img = Image.open(BytesIO(response.content))

        # FIX: Rotate image based on EXIF orientation data
        p_img = ImageOps.exif_transpose(p_img)

        p_img = p_img.convert("RGBA")
        size = (460, 460)
        p_img = ImageOps.fit(p_img, size, centering=(0.5, 0.5))

        mask = Image.new('L', size, 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse((0, 0) + size, fill=255)
        p_img.putalpha(mask)

        # Thick White Border for the Profile Pic
        draw.ellipse([(300, 100), (300+480, 100+480)], outline="white", width=15)
        card.paste(p_img, (310, 110), p_img)
    except Exception as e:
        print(f"Birthday Bot Error: {e}")
        pass

    # HAPPY BIRTHDAY (White)
    draw.text((width/2, 660), "HAPPY BIRTHDAY", fill="white", font=font_lg, anchor="mm")

    # FULL NAME (Bright Yellow - stands out)
    full_name = f"{user_data.get('first_name', '')} {user_data.get('last_name', '')}".upper()
    draw.text((width/2, 790), full_name, fill="#FFD700", font=font_md, anchor="mm")

    # FACULTY | BATCH (White)
    info_text = f"{user_data.get('faculty', 'NSBM STUDENT')} | {user_data.get('batch', '')}".upper()
    draw.text((width/2, 895), info_text, fill="white", font=font_sm, anchor="mm")

    # BRANDING (NSBM Green)
    draw.text((width/2, 1000), "- NSBM COMMUNITY -", fill=(143, 199, 64), font=font_sm, anchor="mm")

    img_byte_arr = BytesIO()
    card.save(img_byte_arr, format='JPEG', quality=100)
    return img_byte_arr.getvalue()

@scheduler_fn.on_schedule(schedule="0 0 * * *")
def birthday_bot_trigger(event: scheduler_fn.ScheduledEvent) -> None:
    db = firestore.client()
    bucket = storage.bucket()

    today = dt_module.date.today()
    today_match = f"-{today.month}-{today.day}"

    users_ref = db.collection('users')
    docs = users_ref.get()

    for doc in docs:
        user = doc.to_dict()
        birthday = str(user.get('birthday', ''))

        if birthday.endswith(today_match):
            image_bytes = generate_birthday_card(user)

            now_str = dt_module.datetime.now().strftime("%H%M%S")
            filename = f"birthdays/{doc.id}_{today}_{now_str}.jpg"
            blob = bucket.blob(filename)
            blob.upload_from_string(image_bytes, content_type='image/jpeg')
            blob.make_public()

            db.collection('posts').add({
                'author_id': 'system_bot_account',
                'category': 'Birthday Wishes',
                'description': f"Wishing a very Happy Birthday to {user.get('initials')} {user.get('first_name')} {user.get('last_name')} {user.get('surname')} from the {user.get('batch')} batch! 🎂🎉 May your day be as bright as your future and filled with both learning and laughter!",
                'image_url': blob.public_url,
                'likes': [],
                'dislikes': [],
                'timestamp': firestore.SERVER_TIMESTAMP,
                'title': f"Happy Birthday {user.get('first_name')} {user.get('last_name')}!"
            })

@scheduler_fn.on_schedule(schedule="every 1 hours")
def delete_old_birthdays(event: scheduler_fn.ScheduledEvent) -> None:
    db = firestore.client()
    bucket = storage.bucket()

    # 1. Calculate the time 24 hours ago from now
    # We use UTC to match Firestore's SERVER_TIMESTAMP
    cutoff = dt_module.datetime.now(dt_module.timezone.utc) - dt_module.timedelta(hours=24)

    # 2. Query only the "Birthday Wishes" category posts older than 24 hours
    old_posts = db.collection('posts') \
        .where('category', '==', 'Birthday Wishes') \
        .where('timestamp', '<=', cutoff) \
        .get()

    print(f"Cleanup started. Found {len(old_posts)} expired birthday posts.")

    for doc in old_posts:
        data = doc.to_dict()

        # 3. Delete the actual image file from Storage to save space/cost
        image_url = data.get('image_url')
        if image_url:
            try:
                # This logic extracts the file path from the Firebase public URL
                # Works for paths like: birthdays/user_id_date.jpg
                path = image_url.split("/o/")[1].split("?")[0].replace("%2F", "/")
                bucket.blob(path).delete()
                print(f"Deleted image from storage: {path}")
            except Exception as e:
                print(f"Could not delete image file: {e}")

        # 4. Delete the Firestore document
        doc.reference.delete()
        print(f"Deleted Firestore document: {doc.id}")



@firestore_fn.on_document_created(document="announcements/{docId}", region="asia-south1")
def send_announcement_notification(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]):
    doc_snapshot = event.data
    if not doc_snapshot:
        return

    # Extract data from the new announcement document
    data = doc_snapshot.to_dict()
    title = data.get('title', 'New Announcement')
    body = data.get('body', '')
    recipients = data.get('recipients', [])
    mode = data.get('mode', '')

    print(f"DEBUG: Processing announcement {event.params['docId']} in mode: {mode}")

    db = firestore.client()
    tokens = []

    try:
        # --- 1. Mode: ALL STUDENTS ---
        if mode == "all":
            users_ref = db.collection("users").where("fcm_token", "!=", None).get()
            tokens = [u.to_dict().get('fcm_token') for u in users_ref if u.to_dict().get('fcm_token')]

        # --- 2. Mode: SPECIFIC INDIVIDUALS ---
        elif mode == "specific":
            uids = [r.get('uid') for r in recipients if r.get('uid')]
            print(f"DEBUG: Targeting UIDs: {uids}")

            for uid in uids:
                user_doc = db.collection("users").document(uid).get()
                if user_doc.exists:
                    t = user_doc.to_dict().get('fcm_token')
                    if t:
                        tokens.append(t)

        # --- 3. Mode: SPECIFIC GROUPS ---
# --- UPDATED GROUP LOGIC ---
        elif mode == "group":
            token_set = set()
            print(f"DEBUG: Processing {len(recipients)} group(s)")

            for group in recipients:
                # START HERE: Always ensure we only get users with tokens
                query = db.collection("users").where("fcm_token", "!=", None)

                batch = group.get('batch')
                faculty = group.get('faculty')
                degree = group.get('degree')

                print(f"DEBUG: Group Filter Input - B: {batch}, F: {faculty}, D: {degree}")

                # Only apply filters if they are NOT "All..."
                if batch and "All" not in str(batch):
                    query = query.where("batch", "==", batch)

                if faculty and "All" not in str(faculty):
                    query = query.where("faculty", "==", faculty)

                if degree and "All" not in str(degree):
                    query = query.where("degree", "==", degree)

                results = query.get()
                print(f"DEBUG: This specific group query found {len(results)} users.")

                for doc in results:
                    t = doc.to_dict().get('fcm_token')
                    if t:
                        token_set.add(t)

            tokens = list(token_set)

        print(f"DEBUG: Found {len(tokens)} tokens to notify.")

        # --- 4. SENDING THE NOTIFICATION ---
        if tokens:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                # This configuration triggers the 'Heads-up' banner on Android
                android=messaging.AndroidConfig(
                    priority='high', # Delivery priority
                    notification=messaging.AndroidNotification(
                        channel_id='high_importance_channel', # Matches Manifest/Main.dart
                        priority='high', # Display priority
                        default_sound=True,
                    ),
                ),
                data={
                    "docId": event.params["docId"],
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                },
                tokens=tokens
            )

            # Use the latest SDK method: send_each_for_multicast
            response = messaging.send_each_for_multicast(message)

            print(f"DEBUG: Successfully sent {response.success_count} notifications.")
            if response.failure_count > 0:
                print(f"DEBUG: {response.failure_count} messages failed to send.")
        else:
            print("DEBUG: No tokens found for this target.")

    except Exception as e:
        print(f"ERROR: {e}")

    return None


@scheduler_fn.on_schedule(
    schedule="0 7 * * *",
    timezone="Asia/Colombo",
    region="asia-south1"
)
def send_daily_event_reminders(event: scheduler_fn.ScheduledEvent) -> None:
    db = firestore.client()
    sl_tz = pytz.timezone("Asia/Colombo")
    now_sl = datetime.now(sl_tz)

    # Calculate the 3 target dates as strings to match your format
    target_dates = []
    for i in range(3):
        d = (now_sl + dt_module.timedelta(days=i)).date()
        # Format: "D/M/YYYY" (Matches your "8/4/2026" format)
        target_dates.append(f"{d.day}/{d.month}/{d.year}")

    print(f"DEBUG: Looking for events on these dates: {target_dates}")

    try:
        # 1. Fetch ALL events (since we can't filter string dates easily in Firestore)
        all_events_ref = db.collection("events").get()

        # 2. Filter events in Python that match our 3 target date strings
        upcoming_events = []
        for doc in all_events_ref:
            ev_data = doc.to_dict()
            ev_date_str = str(ev_data.get('date', '')).strip()
            if ev_date_str in target_dates:
                upcoming_events.append(ev_data)

        print(f"DEBUG: Found {len(upcoming_events)} matching events.")

        if not upcoming_events:
            return

        # 3. Get Student Tokens
        users_ref = db.collection("users").where(filter=google_firestore.FieldFilter("fcm_token", "!=", None)).get()
        all_tokens = [u.to_dict().get('fcm_token') for u in users_ref if u.to_dict().get('fcm_token')]

        if not all_tokens:
            print("DEBUG: No tokens found in users collection.")
            return

        # 4. Loop through matched events and send notifications
        for ev in upcoming_events:
            title = ev.get('title', 'Upcoming Event')
            date_val = ev.get('date', '')
            start = ev.get('start_time', 'TBA')
            end = ev.get('end_time', 'TBA')

            # Determine relative label for the body
            today_str = target_dates[0]
            tomorrow_str = target_dates[1]

            if date_val == today_str:
                day_label = "today"
            elif date_val == tomorrow_str:
                day_label = "tomorrow"
            else:
                day_label = date_val

            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=f"Event Reminder for {title}",
                    body=f"{title} will be held on {day_label}. from {start} to {end}. Stay Tuned!",
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='high_importance_channel',
                        priority='high',
                        default_sound=True,
                    ),
                ),
                tokens=all_tokens
            )

            response = messaging.send_each_for_multicast(message)
            print(f"DEBUG: Notification sent for {title}. Success: {response.success_count}")

    except Exception as e:
        print(f"ERROR in event reminder: {e}")