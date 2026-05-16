import firebase_admin
from firebase_admin import credentials, db

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://home-electrical-tracking-54460-default-rtdb.asia-southeast1.firebasedatabase.app/'
})

ref = db.reference('/pengujian')
ref.delete()