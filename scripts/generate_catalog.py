import json
import random

# Core data structure to generate products
categories_data = {
    "Vegetables": {
        "count": 40,
        "items": [
            ("Potato", "आलू", ["aloo", "potato", "spud"]),
            ("Onion", "प्याज़", ["pyaaj", "onion", "bulb"]),
            ("Tomato", "टमाटर", ["tamatar", "tomato", "red"]),
            ("Garlic", "लहसुन", ["lahsun", "garlic"]),
            ("Ginger", "अदरक", ["adrak", "ginger"]),
            ("Spinach", "पालक", ["palak", "spinach", "leafy"]),
            ("Coriander", "धनिया", ["dhania", "coriander", "cilantro"]),
            ("Carrot", "गाजर", ["gajar", "carrot"]),
            ("Cabbage", "बंदगोभी", ["bandh gobhi", "cabbage"]),
            ("Capsicum", "शिमला मिर्च", ["shimla mirch", "capsicum"]),
            ("Cucumber", "खीरा", ["khira", "cucumber"]),
            ("Broccoli", "ब्रोकोली", ["broccoli"]),
            ("Cauliflower", "फूलगोभी", ["phool gobhi", "cauliflower"]),
            ("Green Chili", "हरी मिर्च", ["hari mirch", "green chili"]),
            ("Lady Finger", "भिंडी", ["bhindi", "lady finger", "okra"]),
            ("Bottle Gourd", "लौकी", ["lauki", "bottle gourd", "dudhi"]),
            ("Bitter Gourd", "करेला", ["karela", "bitter gourd"]),
            ("Eggplant", "बैंगन", ["baingan", "eggplant", "brinjal"]),
            ("Radish", "मूली", ["mooli", "radish"]),
            ("Pumpkin", "कद्दू", ["kaddu", "pumpkin"]),
        ],
        "units": ["kg", "500g", "250g"],
        "price_range": (20, 100),
    },
    "Fruits": {
        "count": 30,
        "items": [
            ("Apple", "सेब", ["seb", "apple"]),
            ("Banana", "केला", ["kela", "banana"]),
            ("Orange", "संतरा", ["santra", "orange"]),
            ("Mango", "आम", ["aam", "mango"]),
            ("Grapes", "अंगूर", ["angoor", "grapes"]),
            ("Papaya", "पपीता", ["papita", "papaya"]),
            ("Watermelon", "तरबूज", ["tarbooj", "watermelon"]),
            ("Pomegranate", "अनार", ["anaar", "pomegranate"]),
            ("Guava", "अमरूद", ["amrood", "guava"]),
            ("Pineapple", "अनानास", ["ananas", "pineapple"]),
        ],
        "units": ["kg", "dozen", "piece"],
        "price_range": (40, 200),
    },
    "Dairy": {
        "count": 35,
        "items": [
            ("Milk", "दूध", ["doodh", "milk"]),
            ("Curd", "दही", ["dahi", "curd", "yogurt"]),
            ("Paneer", "पनीर", ["paneer", "cottage cheese"]),
            ("Cheese", "चीज़", ["cheese"]),
            ("Butter", "मक्खन", ["makhan", "butter"]),
            ("Ghee", "घी", ["ghee", "clarified butter"]),
            ("Cream", "मलाई", ["malai", "cream"]),
            ("Lassi", "लस्सी", ["lassi", "buttermilk"]),
        ],
        "brands": ["Amul", "Mother Dairy", "Nandini", "Britannia"],
        "units": ["1L", "500ml", "200g", "1kg", "500g"],
        "price_range": (20, 500),
    },
    "Rice": {
        "count": 20,
        "items": [
            ("Basmati Rice", "बासमती चावल", ["basmati", "rice", "chawal"]),
            ("Brown Rice", "ब्राउन राइस", ["brown rice", "chawal"]),
            ("Sona Masoori", "सोना मसूरी", ["sona masoori", "rice"]),
            ("Jasmine Rice", "चमेली चावल", ["jasmine rice"]),
        ],
        "brands": ["India Gate", "Daawat", "Kohinoor", "Fortune"],
        "units": ["1kg", "5kg", "10kg"],
        "price_range": (60, 1500),
    },
    "Flour": {
        "count": 20,
        "items": [
            ("Wheat Flour", "गेहूं का आटा", ["ata", "atta", "wheat flour"]),
            ("Rice Flour", "चावल का आटा", ["rice flour", "chawal atta"]),
            ("Besan", "बेसन", ["besan", "gram flour"]),
            ("Maida", "मैदा", ["maida", "refined flour"]),
            ("Ragi Flour", "रागी का आटा", ["ragi", "finger millet"]),
            ("Cornflour", "मक्के का आटा", ["cornflour", "makki atta"]),
        ],
        "brands": ["Aashirvaad", "Pillsbury", "Fortune", "Nature Fresh"],
        "units": ["1kg", "5kg", "500g"],
        "price_range": (40, 300),
    },
    "Pulses": {
        "count": 35,
        "items": [
            ("Toor Dal", "तूर दाल", ["toor", "arhar", "dal"]),
            ("Moong Dal", "मूंग दाल", ["moong", "dal"]),
            ("Masoor Dal", "मसूर दाल", ["masoor", "dal"]),
            ("Chana Dal", "चना दाल", ["chana", "dal"]),
            ("Urad Dal", "उड़द दाल", ["urad", "dal"]),
            ("Rajma", "राजमा", ["rajma", "kidney beans"]),
            ("Kabuli Chana", "काबुली चना", ["chole", "chickpeas"]),
        ],
        "brands": ["Tata Sampann", "Catch", "Fortune"],
        "units": ["500g", "1kg", "2kg"],
        "price_range": (60, 300),
    },
    "Oils": {
        "count": 20,
        "items": [
            ("Mustard Oil", "सरसों का तेल", ["sarso tel", "mustard oil"]),
            ("Sunflower Oil", "सूरजमुखी का तेल", ["sunflower oil", "refined oil"]),
            ("Groundnut Oil", "मूंगफली का तेल", ["mungfali tel", "groundnut oil"]),
            ("Olive Oil", "जैतून का तेल", ["olive oil"]),
            ("Coconut Oil", "नारियल का तेल", ["nariyal tel", "coconut oil"]),
        ],
        "brands": ["Fortune", "Saffola", "Dhara", "Patanjali", "Borges"],
        "units": ["1L", "5L", "500ml"],
        "price_range": (100, 1000),
    },
    "Spices": {
        "count": 50,
        "items": [
            ("Turmeric Powder", "हल्दी पाउडर", ["haldi", "turmeric"]),
            ("Red Chili Powder", "लाल मिर्च पाउडर", ["lal mirch", "chili"]),
            ("Coriander Powder", "धनिया पाउडर", ["dhania powder", "coriander"]),
            ("Cumin Seeds", "जीरा", ["jeera", "cumin"]),
            ("Black Pepper", "काली मिर्च", ["kali mirch", "pepper"]),
            ("Garam Masala", "गर्म मसाला", ["garam masala"]),
            ("Chaat Masala", "चाट मसाला", ["chaat masala"]),
            ("Cardamom", "इलायची", ["elaichi", "cardamom"]),
            ("Cinnamon", "दालचीनी", ["dalchini", "cinnamon"]),
            ("Cloves", "लौंग", ["laung", "cloves"]),
        ],
        "brands": ["Everest", "MDH", "Catch", "Suhana"],
        "units": ["50g", "100g", "250g", "500g"],
        "price_range": (20, 400),
    },
    "Snacks": {
        "count": 60,
        "items": [
            ("Potato Chips", "आलू चिप्स", ["chips", "potato chips"]),
            ("Bhujia", "भुजिया", ["bhujia", "sev"]),
            ("Namkeen Mix", "नमकीन मिक्स", ["namkeen", "mixture"]),
            ("Peanuts", "मूंगफली", ["mungfali", "peanuts", "singdana"]),
            ("Kurkure", "कुरकुरे", ["kurkure", "snack"]),
            ("Popcorn", "पॉपकॉर्न", ["popcorn"]),
        ],
        "brands": ["Haldiram's", "Lay's", "Balaji", "Bikaji", "Kurkure"],
        "units": ["50g", "100g", "200g", "400g", "1kg"],
        "price_range": (10, 250),
    },
    "Biscuits": {
        "count": 30,
        "items": [
            ("Marie Biscuit", "मैरी बिस्कुट", ["marie", "biscuit"]),
            ("Digestive Biscuit", "डाइजेस्टिव बिस्कुट", ["digestive", "biscuit"]),
            ("Chocolate Chip Cookies", "चॉकलेट कुकीज़", ["chocolate cookie", "biscuit"]),
            ("Glucose Biscuit", "ग्लूकोज बिस्कुट", ["parle g", "glucose", "biscuit"]),
            ("Cream Biscuit", "क्रीम बिस्कुट", ["cream biscuit", "bourbon", "oreo"]),
        ],
        "brands": ["Britannia", "Parle", "Sunfeast", "Oreo", "McVitie's"],
        "units": ["50g", "100g", "250g", "Family Pack"],
        "price_range": (5, 150),
    },
    "Beverages": {
        "count": 40,
        "items": [
            ("Tea Powder", "चाय पत्ती", ["chai", "tea", "patti"]),
            ("Coffee Powder", "कॉफी पाउडर", ["coffee", "nescafe"]),
            ("Green Tea", "ग्रीन टी", ["green tea", "healthy tea"]),
            ("Cold Drink", "कोल्ड ड्रिंक", ["cola", "thumbs up", "sprite"]),
            ("Fruit Juice", "फलों का रस", ["juice", "real juice", "tropicana"]),
            ("Energy Drink", "एनर्जी ड्रिंक", ["red bull", "energy drink"]),
        ],
        "brands": ["Tata Tea", "Brooke Bond", "Nescafe", "Bru", "Coca Cola", "Pepsi", "Real"],
        "units": ["250g", "500g", "1kg", "500ml", "1L", "2L"],
        "price_range": (40, 500),
    },
    "Household": {
        "count": 50,
        "items": [
            ("Detergent Powder", "सर्फ", ["surf", "detergent", "washing powder"]),
            ("Dishwash Liquid", "बर्तन धोने का तरल", ["vim", "dishwash"]),
            ("Floor Cleaner", "फर्श क्लीनर", ["lizol", "floor cleaner"]),
            ("Toilet Cleaner", "शौचालय क्लीनर", ["harpic", "toilet cleaner"]),
            ("Garbage Bags", "कचरे की थैली", ["garbage bag", "dustbin bag"]),
            ("Mosquito Repellent", "मच्छर भगाने वाला", ["all out", "good knight", "repellent"]),
        ],
        "brands": ["Surf Excel", "Tide", "Ariel", "Vim", "Pril", "Lizol", "Harpic"],
        "units": ["500g", "1kg", "2kg", "500ml", "1L"],
        "price_range": (50, 400),
    },
    "Personal Care": {
        "count": 40,
        "items": [
            ("Bathing Soap", "साबुन", ["sabun", "soap"]),
            ("Shampoo", "शैम्पू", ["shampoo"]),
            ("Toothpaste", "टूथपेस्ट", ["toothpaste", "colgate"]),
            ("Hair Oil", "बालों का तेल", ["hair oil", "parachute"]),
            ("Body Lotion", "बॉडी लोशन", ["lotion", "moisturizer"]),
            ("Deodorant", "डिओडोरेंट", ["deo", "spray"]),
        ],
        "brands": ["Lifebuoy", "Lux", "Dove", "Sunsilk", "Clinic Plus", "Colgate", "Pepsodent", "Parachute", "Nivea", "Fogg"],
        "units": ["100g", "3x100g", "200ml", "500ml", "100ml", "150ml"],
        "price_range": (30, 350),
    },
    "Frozen": {
        "count": 30,
        "items": [
            ("Frozen Peas", "फ्रोजन मटर", ["matar", "peas", "frozen"]),
            ("Frozen Sweet Corn", "फ्रोजन स्वीट कॉर्न", ["corn", "sweet corn", "frozen"]),
            ("French Fries", "फ्रेंच फ्राइज़", ["fries", "potato fries", "frozen"]),
            ("Ice Cream", "आइसक्रीम", ["ice cream", "vanilla", "chocolate"]),
            ("Frozen Paratha", "फ्रोजन पराठा", ["paratha", "frozen"]),
        ],
        "brands": ["Safal", "McCain", "Amul", "Vadilal", "Kwality Walls", "Sumeru"],
        "units": ["200g", "500g", "1kg", "500ml", "1L"],
        "price_range": (50, 400),
    },
}

all_products = []
product_id_counter = 1

def generate_barcode():
    return str(random.randint(1000000000000, 9999999999999))

for category, data in categories_data.items():
    target_count = data["count"]
    items = data["items"]
    brands = data.get("brands", ["Farm Fresh", "Organic India", "Local", "Premium"])
    units = data["units"]
    price_min, price_max = data["price_range"]
    
    generated_for_category = 0
    
    while generated_for_category < target_count:
        item = random.choice(items)
        brand = random.choice(brands)
        unit = random.choice(units)
        
        name_en, name_hi, keywords = item
        
        full_name = f"{brand} {name_en} {unit}" if brand not in ["Local", "Farm Fresh"] else f"{name_en} {unit}"
        
        mrp = random.randint(price_min, price_max)
        selling_price = round(mrp * random.uniform(0.8, 0.95))
        
        product = {
            "id": f"PROD{str(product_id_counter).zfill(4)}",
            "name": full_name,
            "hindiName": name_hi,
            "category": category,
            "subCategory": category,
            "brand": brand,
            "keywords": keywords + [brand.lower(), unit.lower()],
            "aliases": [name_en.lower(), name_hi],
            "mrpPrice": float(mrp),
            "price": float(selling_price),
            "stockQuantity": random.randint(10, 200),
            "unit": unit,
            "barcode": generate_barcode(),
            "description": f"High quality {name_en} from {brand}. Perfect for your daily needs.",
            "nutrition": {"Calories": f"{random.randint(10, 400)} kcal", "Carbs": f"{random.randint(1, 80)}g"},
            "imageUrl": f"https://via.placeholder.com/300?text={name_en.replace(' ', '+')}",
            "isAvailable": True,
            "shopId": "SHOP001",
            "shopName": "Fufaji Main Store",
            "district": "Central",
            "village": "Main City",
            "createdAt": "2026-07-02T12:00:00.000Z",
            "updatedAt": "2026-07-02T12:00:00.000Z",
        }
        
        all_products.append(product)
        product_id_counter += 1
        generated_for_category += 1

# Make sure we exactly have 500
# Actually, the counts add up to 500, but we can just output what we have.

with open('assets/data/products_500.json', 'w', encoding='utf-8') as f:
    json.dump(all_products, f, indent=2, ensure_ascii=False)

print(f"Generated {len(all_products)} products successfully to assets/data/products_500.json")
