# 美食地图数据架构草案

这份文档先定义数据结构，不急着实现功能。目标是让后续接 Supabase / Postgres 时有一套清晰、可扩展、不会太重的地基。

## 当前结论

第一版建议拆成 6 类核心数据：

1. 用户资料：`profiles`
2. 店铺分类：`restaurant_categories`
3. 店铺：`restaurants`
4. 评价：`reviews`
5. 评价图片：`review_images`
6. 评价反馈：`review_reactions`
7. 收藏店铺：`favorites`

密码不要直接放进业务表。注册登录交给 Supabase Auth 处理，业务库里只保存用户昵称、角色、创建时间等资料。

## 用户与权限

### profiles

用于保存真正意义上的用户资料，但不保存明文密码，也不保存密码哈希。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 用户 ID，对应 Supabase Auth 的 `auth.users.id` |
| `display_name` | text | 用户显示名，唯一 |
| `role` | text | `user` 或 `admin` |
| `created_at` | timestamptz | 注册时间 |
| `updated_at` | timestamptz | 更新时间 |

管理员规则建议这样落地：

- 产品层仍然认为“兜兜”是管理员。
- 数据库层不要只靠名字判断权限，而是给这个用户的 `role` 设置为 `admin`。
- 上线前要先注册/创建“兜兜”这个账号，并把它设为管理员。
- 其他用户不能再注册同名，因为 `display_name` 唯一。

这样既符合“管理员姓名为兜兜”的设定，又避免别人改个名字就拿到管理员权限。

## 店铺分类

### restaurant_categories

当前分类写死在前端代码里，后续正式改成从分类表读取，方便以后增加“火锅”“烧烤”“甜品”等分类。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | text | 分类 key，例如 `noodle` |
| `label` | text | 展示名，例如 `面/粉` |
| `icon` | text | 展示图标 |
| `wall_color` | text | 建筑主色 |
| `wall_dark_color` | text | 建筑深色 |
| `roof_color` | text | 屋顶颜色 |
| `accent_color` | text | 点缀色 |
| `sort_order` | integer | 展示顺序 |
| `is_active` | boolean | 是否启用 |

第一版接数据库时就使用分类表。前端初始化时读取 `restaurant_categories`，不再把分类作为主要数据写死在代码里。

## 店铺

### restaurants

从当前 `places` 升级而来。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 店铺 ID |
| `name` | text | 店名 |
| `category_id` | text | 分类 ID |
| `x` | numeric | 自定义地图横向百分比位置，0-100 |
| `y` | numeric | 自定义地图纵向百分比位置，0-100 |
| `avg_price` | numeric | 人均价格，可选 |
| `description` | text | 店铺补充说明，可选 |
| `status` | text | `active` / `hidden` / `deleted` |
| `created_by` | uuid | 建造人 |
| `created_at` | timestamptz | 建造时间 |
| `updated_at` | timestamptz | 更新时间 |

`x` / `y` 仍然保留，因为你现在不是接真实地图，而是在一张自定义地图上放建筑。

未来如果要接真实地图，再加：

| 字段 | 类型 | 说明 |
|---|---|---|
| `latitude` | numeric | 纬度 |
| `longitude` | numeric | 经度 |

## 建造店铺时是否必须填写评价

我建议：第一版建店时仍然要填写一条“首次评价”。

原因：

- 你的产品设定是“吃过才能建”，这条评价就是建店理由。
- 如果允许空店铺，地图上会出现很多只有名字、没有内容的点，质量会下降。
- 数据库结构上，店铺和评价分开保存，但交互上可以一次提交两条数据：先创建店铺，再创建第一条评价。

建议建店表单分成两块：

店铺信息：

- 店名，必填
- 分类，必填
- 地图位置，自动来自点击坐标
- 人均价格，可选

首次评价：

- 星级评分，必填
- 推荐/一般，必填或由星级自动推导
- 吃了什么，可选
- 评价内容，建议必填
- 就餐日期，必填
- 图片，可选

## 评价

### reviews

从当前 `reviews` 对象升级成独立表。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 评价 ID |
| `restaurant_id` | uuid | 对应店铺 |
| `user_id` | uuid | 评价人 |
| `rating` | numeric | 星级评分，1-5 |
| `recommend` | boolean | 是否推荐 |
| `dish_name` | text | 吃的是什么，可选 |
| `comment` | text | 评价正文 |
| `visit_date` | date | 就餐日期，必填 |
| `created_at` | timestamptz | 创建时间 |
| `updated_at` | timestamptz | 更新时间 |
| `status` | text | `active` / `hidden` / `deleted` |

`recommend` 和 `rating` 建议同时保留。

- `rating` 适合算平均分。
- `recommend` 适合做你原来那种“👍 推荐数”的轻量玩法。
- 如果以后觉得重复，可以用规则自动推导，比如 `rating >= 4` 就算推荐。

## 评价图片

### review_images

图片不要直接塞进评价表。评价可以有多张图片，所以单独建表。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 图片 ID |
| `review_id` | uuid | 对应评价 |
| `storage_path` | text | Supabase Storage 路径 |
| `public_url` | text | 展示 URL，可选 |
| `alt_text` | text | 图片说明，可选 |
| `sort_order` | integer | 排序 |
| `created_at` | timestamptz | 上传时间 |

第一版可以限制每条评价最多 3 张图，后续再放开。

## 对评价点赞 / 不认同

### review_reactions

用户不是直接给店铺点赞，而是对某一条评价表达“赞同”或“不认同”。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 反馈 ID |
| `review_id` | uuid | 对应评价 |
| `user_id` | uuid | 反馈用户 |
| `reaction_type` | text | `like` 或 `disagree` |
| `created_at` | timestamptz | 反馈时间 |

关键约束：

- 同一个用户对同一条评价只能有一个反馈。
- 用户可以从 `like` 改成 `disagree`，或取消反馈。
- 展示时通过关联 `profiles.display_name` 能看到“谁点赞/谁不认同”。

## 店铺升级逻辑

我建议把“评价的星级评分”和“评价被点赞/不认同”分开看。

### 不建议

不要直接用“评价被点赞数”当店铺升级依据。因为评价点赞更像是在判断“这条评价有没有帮助”，不一定代表店铺好吃。

例如：

- 一条差评写得很真实，很多人点赞，不代表店铺应该升级。
- 一条好评被很多人不认同，说明这条评价可疑，但不应该直接扣店铺等级。

### 建议第一版升级规则

店铺等级根据店铺自己的评价质量计算：

| 等级 | 名称 | 建议规则 |
|---|---|---|
| 1 | 小吃摊 | 默认 |
| 2 | 路边小店 | 至少 2 条推荐评价，且平均分 >= 3.5 |
| 3 | 人气餐馆 | 至少 5 条推荐评价，且平均分 >= 4.0 |
| 4 | 老字号地标 | 至少 10 条推荐评价，且平均分 >= 4.3 |

评价反馈用于辅助展示：

- “高赞评价”
- “争议评价”
- “大家不太认同这条评价”

这样玩法更清楚：店铺靠真实评价升级，评价靠他人反馈排序。

## 收藏店铺

### favorites

用于支撑“我的足迹”里的收藏店铺功能。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | 收藏 ID |
| `restaurant_id` | uuid | 对应店铺 |
| `user_id` | uuid | 收藏用户 |
| `created_at` | timestamptz | 收藏时间 |

关键约束：

- 同一个用户对同一家店只能收藏一次。
- 用户可以取消收藏，删除对应记录即可。
- “我的足迹”未来建议分成三块：
  - 我建造的店
  - 我点评过的店
  - 我收藏的店

## 旧数据到新数据的映射

当前旧结构：

```js
{
  places: [
    {
      id,
      name,
      category,
      x,
      y,
      addedBy,
      addedAt
    }
  ],
  reviews: {
    [placeId]: [
      {
        reviewer,
        comment,
        recommend,
        timestamp
      }
    ]
  }
}
```

新结构映射：

| 旧字段 | 新表 | 新字段 |
|---|---|---|
| `place.id` | `restaurants` | `legacy_id`，可选迁移字段 |
| `place.name` | `restaurants` | `name` |
| `place.category` | `restaurants` | `category_id` |
| `place.x` | `restaurants` | `x` |
| `place.y` | `restaurants` | `y` |
| `place.addedBy` | `profiles` / `restaurants` | `display_name` / `created_by` |
| `place.addedAt` | `restaurants` | `created_at` |
| `review.reviewer` | `profiles` / `reviews` | `display_name` / `user_id` |
| `review.comment` | `reviews` | `comment` |
| `review.recommend` | `reviews` | `recommend` |
| `review.timestamp` | `reviews` | `created_at` |

迁移时如果旧数据里只有名字、没有真正账号，可以先为这些名字创建“占位用户”。

## 暂时不做但预留的能力

- 店铺标签：以后加 `tags` 和 `restaurant_tags`
- 店铺图片：以后加 `restaurant_images`
- 举报/审核：以后加 `reports` 或 `moderation_logs`
- 管理员删除/恢复：可以先用 `status` 字段实现软删除
