# 基本
Geocoderの基本例は次のとおりです。
地名や住所を引数にして、経度緯度を返り値として取得できます。
```ruby
results = Geocoder.search("Paris")
results.first.coordinates
#=> [48.856614, 2.3522219]  latitude and longitude
```

反対に、経度緯度を引数にして、住所などを取得できます。
```ruby
results = Geocoder.search([48.856614, 2.3522219])
results.first.address
#=> "Hôtel de Ville, 75004 Paris, France"
```

一方で、ipアドレスから場所を取得することも可能です。
```ruby
results = Geocoder.search("172.56.21.89")
results.first.coordinates
#=> [30.267153, -97.7430608]
results.first.country
#=> "United States"
```

# モデルに対するGeocoding
ここからはActiveRecordを使用したモデルに対してGeocoderを利用する方法を紹介していきます。
この際、大事なポイントが**2つ**あります。
1. 地名・住所データを返すメソッドが存在している。
2. 経度・緯度データを格納するカラムが存在している。
3. `geocoded_by` もしくは `reverse_geocoded_by` をモデルに記述している。

### 1. 地名・住所データを返すメソッドが存在している
地名・住所データを返すメソッドがあればよいので、データベースのカラムとして持つか、モデル内にメソッドを用意しましょう。

[例示コード](GithubURL)では、データベースのカラムとしてaddressを用意しています。
モデル内にメソッドを設ける場合は、特定の場所や、複数カラム組み合わせて返すなど工夫を凝らすことが容易になります。
```ruby
class Model < ApplicationRecord
  def current_position
    #現在地を返す
  end

  def address
    [street, city, state, country].compact.join(', ')
  end
end
```

### 2. 経度・緯度データを格納するカラムが存在している。
デフォルトの設定だと、`latitude`と`longitude`というカラムを用意する必要があります。
これは、モデルで設定を変更できます。
```ruby
class Model < ApplicationRecord
  #lat, lonというカラムを設ける場合
  geocoded_by :address, latitude: :lat, longitude: :lon  # ActiveRecord
end
```
### 3. `geocoded_by` もしくは `reverse_geocoded_by` をモデルに記述している。
すでに`2. 経度・緯度データを格納するカラムが存在している。`で記述してしまいましたが、`geocoded_by`か`reverse_geocoded_by`を記述することで、モデルを介してgeocoderのメソッドを使えるようになります。

`reverse_geocoded_by`は経度緯度でgeocodingしたい場合に記述します。

```ruby
  obj.distance_to([43.9,-98.6])  # distance from obj to point
  obj.bearing_to([43.9,-98.6])   # bearing from obj to point
  obj.bearing_from(obj2)         # bearing from obj2 to obj
```

---
ActiveRecordのモデルに対してGeocoderを備え付ける方法はこれまでのとおりです。
ここからは例を示しながらGeocoderで使えるメソッドを紹介していきます。
ここではSpotモデルを作成し、そのモデルで遊んでいきます。

[サンプルコード]()では適当なデータをseed.rbに入れてあります。

### geocode
`geocode`メソッドでgeocodingできます。
`after_validation`のコールバックとしてgeocodeを行う例をよく見ます。

```ruby
class Spot < ApplicatoinRecord
  geocoded_by :address
  after_validation :geocode
end
```

```ruby
Spot.create(:address => "東京タワー")

=> #<Spot id: 1, address: "東京タワー", latitude: 35.65858645, longitude: 139.745440057962, created_at: "2019-12-05 06:06:19", updated_at: "2019-12-05 06:06:19">
```

### 距離算出
距離算出には、`distance_to`、`distance_from`が使えます。
ただし、geocoderの距離単位はデフォルトでmileになっています。
```ruby
  spot1 = Spot.find(1)
  spot2 = Spot.find(2)
  spot1.distance_to(spot2)
  spot1.distance_from([35.65858645, 139.745440057962])
```

### 近いやつ取得
多くの初心者エンジニアが使ってみたい機能ですね。
geocoderだとめちゃめちゃかんたんです。
```ruby
  Spot.near("新宿") #20mileで検索
  spot = Spot.find(1)
  spot.nearbys(5, units: :km) #5kmで検索
```

検索SQL見ると楽しいです。力技過ぎて笑えます。
こんなものなんでしょうか。
```sql
SELECT  spots.*, (69.09332411348201 * ABS(spots.latitude - 35.6891183) * 0.7071067811865475) + (59.836573914187355 * ABS(spots.longitude - 139.7010768) * 0.7071067811865475) AS distance, CASE WHEN (spots.latitude >= 35.6891183 AND spots.longitude >= 139.7010768) THEN  45.0 WHEN (spots.latitude <  35.6891183 AND spots.longitude >= 139.7010768) THEN 135.0 WHEN (spots.latitude <  35.6891183 AND spots.longitude <  139.7010768) THEN 225.0 WHEN (spots.latitude >= 35.6891183 AND spots.longitude <  139.7010768) THEN 315.0 END AS bearing FROM "spots" WHERE (spots.latitude BETWEEN 35.3996547337783 AND 35.978581866221695 AND spots.longitude BETWEEN 139.34467987351536 AND 140.05747372648466) ORDER BY distance ASC LIMIT ? 
```

### 中間地点を取得
これぐらい自分で計算できますが、メソッドを用意してくれてます。
マッチングアプリでお互いの中間地点にあるスポット検索とかできたら便利ですね。

```ruby
spot1 = Spot.find(1)
spot2 = Spot.find(2)
Geocoder::Calculations.geographic_center([spot1, spot2]) #引数は3箇所以上可能
=> #[35.68432475413425, 139.77806655172708]
```

### Geocodingの設定
距離の単位をkmにしたり、Geocodingを外部APIにするなどの設定を行うことができます。
`rails g geocoder:config`
で設定ファイルを生成できます。

```ruby:geocoder.rb
Geocoder.configure(
  units: :km
)
```

googleのgeocoding APIを使用する場合は次のように設定します。
```ruby:geocoder.rb
Geocoder.configure(
  lookup: :google, 
  api_key: '---------YOUR_API_KEY---------',     
)
```

その他のGeocoding APIを使用する場合は[API_GUIDE](https://github.com/alexreisner/geocoder/blob/master/README_API_GUIDE.md)を参照してください。
