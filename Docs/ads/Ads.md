#  Ads Spec  

- Dans `processed_subset_tweet.json` tu trouveras 34 tweets.
- Dans `onehot_user_profile.json`  y a le vecteur en representation one hot (0, 1) des user de taille (nb user: 34, nb features: 62)
Un tweet est sous forme de tuple (pseudo, gender, age, spoken languages, marital status, has kids or not, country, areas of interests, list of tweets), eg:

```
('Alexjonline',
  'male',
  30,
  ['English', 'Hindi'],
  'single',
  0,
  'India',
  ['Tech', 'Photography'],
  ['Just wondering how much more hotter Chennai is gonna get in May! ',
   'Searching for photograph of escaping car from a traffic jam...tried all strings on google... ',
   '@roshnimo Dont be lazy............try a few out.... tools are to make life easy for lazy people ',
   '@far1983 Nothing really man..Hwz you..Bad that I got to rush to office now ',
   '@Spitphyre yeah you should..that better for us..No offence meant ']),
```

- Dans `ads_files.json` tu trouveras les publicités sous format dict id -> ad
- Dans `onehot_ads.json`  y a le vecteur en representation  one hot (0, 1) des publicités de taille (nb ads: 4434, nb features: 62)
Une publicité est définie comme un tuple `(ad_title, ad_country, target_countries, ad_language, target_age_group, target_gender, area of interests, weighted_interest, description, image_path)`

Le `weighted_interest` est utilisé pour ponderer le dot product.
Eg:
```
 2: ('长城探险之旅',
  3,
  [3],
  ['Mandarin'],
  [1, 2, 3],
  [0, 1],
  ['Travel', 'Sports'],
  [5, 4],
  '挑战长城，享受户外探险和运动的乐趣，适合所有年龄的家庭！马上预订，开始难忘的旅行！',
  'img_travel_sports_china_0.png'),
```

Pour l'instant, nous avons 62 features (caractéristiques) qui est une concatenation des informations:
```
feature_vector = (
            onehot_gender              # de taille 2 pour les genres 0: female, 1: male <!> une publicité pour cibler un ou plusieurs genres
            + onehot_age                 # de taille 5
            + onehot_language        # de taille 11
            + onehot_kids_ads         # de taille 1. 1: si la publicité cible des enfants , 0 sinon
            + onehot_country          # de taille 13
            + onehot_interests          # de taille 30, car on a 30 categories pour l'instant
        )
```

## Gender
`{"female": 0, "male": 1}`

## Marital Status
`{"single": 0, "engaged": 1}`

## Interests
```
['Animals', 'Art', 'Automobiles', 'Bicycle', 'Books', 'Comedy', 'Comics', 'Culture', 'Education', 'Family', 'Fashion', 'Food', 'Health', 'Journalism', 'Movies', 'Music', 'Nature', 'News', 'Pets', 'Photography', 'Politics', 'Science', 'Smartphones', 'Software Dev', 'Sports', 'TV', 'Tech', 'Travel', 'Video Games', 'Writers']
```

## Age
```
    if age <= 12:
        then 0 (AgeGroup.CHILD)
    if 12 < age <= 19:
        then 1 (AgeGroup.ADOLESCENT)
    if 19 < age <= 45:
        then 2 (AgeGroup.YOUNG_ADULT)
    if 45 < age <= 60:
        then 3 (AgeGroup.MIDDLE_ADULT)
    else 4 AgeGroup.SENIOR
```

## Country
```
 {
    "Abu_Dhabi": 0,
    "United_States": 1,
    "France": 2,
    "China": 3,
    "Germany": 4,
    "United_Kingdom": 5,
    "Japan": 6,
    "India": 7,
    "Canada": 8,
    "Italy": 9,
    "Algeria": 10,
    "Australia": 11,
    "Spain": 12,
}
```

## Language
```
{
    "Abu_Dhabi": ["Arabic", "English"],  
    "United_States": ["English", "Spanish"], 
    "France": ["French", "English"],  
    "China": ["Mandarin"], 
    "Germany": [
        "German"
    ], 
    "United_Kingdom": ["English"],
    "Japan": ["Japanese
    "India": [
        "Hindi",
        "Tamil",
    ],  
    "Canada": ["English", "French"],
    "Italy": ["Italian"],  
    "Algeria": ["Tamazight", "French", "Arabic"],
    "Australia": ["English"], 
    "Spain": [
        "Spanish"

    ], 
}
```
