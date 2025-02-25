#  Ads Spec  

- Dans `ads_files.json` tu trouveras les publicités sous format dict id -> ad
Une publicité est définie comme un tuple `(ad_title, ad_country, target_countries, ad_language, target_age_group, target_gender, area of interests, weighted_interest, description, image_path)`

Pour l'instant, nous avons 62 features (caractéristiques) qui est une concatenation des informations:
```
feature_vector = (
    onehot_gender       # de taille 2 pour les genres 0: female, 1: male <!> une publicité pour cibler un ou plusieurs genres
    + onehot_age        # de taille 5
    + onehot_language   # de taille 11
    + onehot_kids_ads   # de taille 1. 1: si la publicité cible des enfants , 0 sinon
    + onehot_country    # de taille 13
    + onehot_interests  # de taille 30, car on a 30 categories pour l'instant
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
