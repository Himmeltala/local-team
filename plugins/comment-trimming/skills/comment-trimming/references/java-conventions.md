# Java 注释做法

以下是**团队标准**，对所有 Java 项目生效，不限某个仓库。样例取自存量代码，不是通用社区建议——写新代码时对齐这些形态，别引入外部风格。

## 类头 Javadoc（团队主流写法）

```java
/**
 * <p>
 * <b>功能：</b>提醒消息控制层
 * <b>说明：</b>基础 CRUD，含标记已读与未读数量
 * </p>
 *
 * @author runnet
 */
@Api(tags = "提醒消息")
@RestController
@RequestMapping("/remindMessage")
@Slf4j
public class RemindMessageController {
```

- `功能：` 一行说清这个类负责什么。<b>tag 是既有模板的一部分，保留。</b>
- `说明：` 可选，**最多一行**。只在有非显然内容时写：口径约定、单位与精度、已知的坑、本类自己的约束。不写调用关系与调用链（谁调用它、它写的数据谁消费），那类信息用查找引用看。`功能：` 加 `说明：` 整个正文两行封顶。
- 没有可说的内容就别写 `说明：`，不要留一行空的占位。
- `@author` 保留原值，不要改成自己的名字。

## 类头 Javadoc（历史写法，存量里仍有）

```java
/**
 * @author hyd
 * @title: IdsQuery
 * @description: ID查询参数封装类，用于接收和解析以逗号分隔的ID字符串
 * @date 2023/7/2519:11
 */
```

改到这类文件时**保持头部原样**，不要重写成新模板。无意义的大 diff 比风格不一致更糟。新类用上面的新模板。

注意 `@date 2023/7/2519:11` 这种缺空格的写法是历史录入问题，不必去修，除非本次改动本来就动了那一行。

## 字段

```java
@ApiModelProperty(value = "按照,分割的ID字符串")
private String ids;
```

- 字段用 `@ApiModelProperty` 表达含义，**不要**在字段上写 Javadoc。
- 入参必填加 `required = true`。
- 禁止在字段上方再叠一行 `// 用户ID` 复述。注解已经写了。

## 方法与接口

```java
@ApiOperation("提醒消息分页列表")
@GetMapping("/page")
public JsonResult<PageResult<RemindMessage>> page(RemindMessageQuery query) {
```

- 控制层方法用 `@ApiOperation`。带复杂参数说明时可用 `@ApiOperation(value = ..., notes = ...)`，`notes` 写清业务口径，同样不要摊成一段。
- Service 内部方法、私有方法不加注解，也不写 Javadoc。方法名和签名能说明的事不必再写一遍。
- 不要为了"看起来很规范"给每个方法补 Javadoc——那是噪音，且与存量风格冲突。

## 行内注释：只讲"为什么"，一行写完

真实好例：

```java
// 查询即视为已读：查询后把当前单位所有未读消息标记为已读
remindMessageService.markAllRead();
```

这行讲的是代码看不出来的业务决定，值得留。同类内容要写两句以上时，说明这段知识该挪进命名或文档，不要继续往注释上叠。

该删的反例：

```java
// ==================== 用户相关 ====================

// 校验参数
if (StringUtils.isBlank(query.getId())) { ... }

// 循环遍历列表
for (RemindMessage m : list) { ... }

// TODO 🚀 待优化
// 2024-03-11 张三 新增查询条件
// private String oldField;

/** 构造方法 */
public UserServiceImpl() {}
```

- 分割线横幅：装饰，删。
- `// 校验参数`、`// 循环遍历列表`：复述代码，删。
- `TODO` 保留，emoji 去掉，补上要做什么。
- 变更履历：版本库已经记录了，删。
- 注释掉的死代码：删。要留就说明原因，否则它是垃圾。
- 简单方法上的 Javadoc：删。

## 边界

保存业务判断与口径的注释要留，但**留不等于写长**。以下是取自本仓库的真实例子，括号里是压缩后的写法：

`DoorRecordServiceImpl.java:173`（私有方法的 Javadoc——例外：这里的口径本身是知识，值得写。原来两行，压成一行）：

```java
/**
 * 登录人下辖的下级区域（省取市、市取区县），区县无下级时返回本级，无区域或区域码非法时返回空列表
 */
private List<SysRegion> listSubRegions() {
```

`RemindMessageController.java:43`（方法体内的行内注释）：

```java
// 查询即视为已读：查询后把当前单位所有未读消息标记为已读
remindMessageService.markAllRead();
```

判断标准有两条，先问留不留，再问长不长：**删掉这行，后来人会误改或看不懂吗？** 会就留；**留下的话，一行写得完吗？** 写不完就压到一行，压不下去又丢不得的报给用户。（同一套标准在 `trim-rules.md` 里也有，`comment-trimmer` 子代理以那份为准。）

## 相关：mapper XML 与 SQL 注释

改到 MyBatis mapper XML 时遵守单独一份做法，见 `xml-sql-conventions.md`。那里的 `--` 注释承载不少业务口径，不要当噪音删。
