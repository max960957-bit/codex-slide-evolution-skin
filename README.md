# Codex Slide Evolution Skin

Windows Codex Desktop 社区换肤工具：六档系列背景、EX 视频、Liquid Studio 控制面板和自定义皮肤 ZIP 导入。

## 使用入口

- [产品说明](产品说明.md)：功能、兼容范围和已知限制。
- [五分钟入门](傻瓜式教程.md)：下载、安装、启动和结束。
- [详细使用手册](使用说明.md)：面板操作、导入机甲皮肤、升级、备份、卸载和排错。
- [制作自己的皮肤](皮肤制作说明.md)：素材准备、配置格式和 ZIP 分享。
- [下载完整工具包](https://github.com/max960957-bit/codex-slide-evolution-skin/releases)。

当前代码限定 Windows 11 x64、官方 Store Codex `26.901.6511.0`。这是社区预览工具，不是 OpenAI 官方插件。

**源码更新不等于下载包更新。** 断线恢复修复已进入 main，v0.1.4 完整包包含该修复和第二套“机甲”皮肤。旧 v0.1.3 ZIP 不包含这些更新。

## 历史实验记录

以下保留开发过程的历史记录；其中旧入口、待办和阶段性结论不代表当前用户操作。日常使用以上面的手册为准。

2026-09-08 实机补充：095519-d125b34b 和 100459-e9d7ed29 两轮均 NativeContent=APPLIED，Sequence=PARTIAL，PendingMaterialChecks=NONE，全部清理及 OrdinaryCodexRestored=PASS，FailureReason=NONE。100459 的 GlassSHA256 与当前无气泡 glass.js 一致；用户已认可当前视觉方向。两轮并未完整覆盖六档/EX，也不能代替长期运行及生成中消息验证。

## 当前推进：D6 六张主线图 + EX 原视频

产品化第一批：visual-core 保存原正式项目的 17 个必要核心/素材文件及 SHA256 清单，build-sequence.js 从随附核心构建，默认基线哈希继续校验。skin-pack.js 接受数据型 skin.json、六 PNG、EX PNG/MP4，限制路径、大小和图片尺寸，不执行皮肤脚本。D6 通过 -SkinDirectory 接入自定义皮肤，并从构建输出 bootstrap PNG 启动，避免先显示默认 L1；D6 使用 CoreBaselineValidation，原 Git 基线字段记 NOT_APPLICABLE_BUNDLED_CORE，D4/D5 仍保留开发检查。选择入口为启动自定义皮肤.cmd；制作示例见 skins/example 和皮肤制作说明.md。

便携测试包 dist/portable-20260908-140157-db360edf.zip（32140543 字节）已生成，39 个文件哈希核验通过，不包含 runs、runtime、截图、机器快捷方式或其他自定义皮肤。包内目录独立构建通过；本地素材边界/替换、六档/视频、玻璃恢复、PowerShell 5.1/7 自定义预检通过。预检使用不存在的原项目路径证明 D6 不依赖原 Git 工作区。仍依赖已安装 Node.js 24 和官方 Codex 26.901.6511.0；文件夹皮肤可用，ZIP 导入、免依赖安装器、干净电脑实机测试及素材公开许可尚未完成。未发布到外部平台。

当前验收基线：用户明确确认新版“启动和两项联动都正常”。134443-06714ed2 记录 exSeen/videoPlayed=true、返回 L2、busy=false、stopRequested=true，全部退出清理和普通 Codex 恢复 PASS，无失败；未访问 L4且结束时 NativeContent=NOT_FOUND，仍保留 PARTIAL。133739-e72e312b 的 l1-visual-injection 通信失败及清理重连身份变化保留，不归因于用户手动关闭，也不因后续成功而删除。新增 native-content.test.js 本地分段回复到最终标记接续、旧样式恢复、草稿/焦点保留检查通过；真实生成和长期稳定性仍未验收。当前视觉和原生联动不再改版。

2026-09-08 更新适配：131645-375c364a、132950-e8e81daf 均在启动前被旧版本校验拦截，FailureReason 为安装版本 26.901.6511.0 与预期 26.901.5280.0 不符；后续 NOT_CHECKED 不代表运行失败。已只读核对新版安装包中的主区域、输入框、侧栏、最终回复标记及原生 Power/fast-mode 属性，更新 ExpectedVersion 为 26.901.6511.0，保留严格版本和签名校验。PowerShell 5.1/7 静态检查、Store 签名、BOM、素材和项目检查通过；未自动重启 Codex，新版实机注入及视觉仍待验证。

EX 联动更新（取代下文独立 EX 入口方案）：用户指定原生闪电／2× 开关控制 EX。安装包 Power 实现将 fastModeEnabled 写入内部根节点的 data-fast-mode；现读取唯一的 true/false 标记，true 进入 EX，false 返回当前滑块映射的级别。开启期间滑块只更新待返回级别，不重启视频；转场中的快速开关变化保留最新目标，结束当前转场后接续。识别成功隐藏独立 EX/返回按钮。仅跟随属性，不点击开关、不修改服务档位、不发送消息。真实闪电控件联动仍待实机验证。

原生 Power 联动：只读核对 Store 26.901.5280.0 的 app-primary-e4da4cd4dd45.js / impl-b0077961afa9.js，确认 data-reasoning-slider、data-model-picker-power-slider 及其 Radix thumb 的 aria-valuemin/max/now，max 对应 options.length-1，data-selected ticks 对应选项且 data-locked 标注锁定项。sequence-host.js 仅观察这些结构/数字属性，按 round(index/max*5)+1 映射六张图；锁定、无效及歧义不触发切换。不读 React 状态、标签文本、设置存储或业务内容，不写原生控件，不触发原生事件。首次识别隐藏重复六档控件；菜单卸载保留背景，再次打开重读。EX 独立入口保留，原生变化可在 EX 转场后回到主线。清理断开观察器及已登记帧。实机原生联动仍待确认，旧实机报告不能作为此功能通过依据。

当前回复样式：按用户截图反馈，将已接入的助手最终回复改为无气泡文字，背景透明、无背景图、无 backdrop blur、无边框颜色及 box-shadow；六档和 EX 切换均保持透明，只沿用各档文字颜色。保持原生布局、代码块内部样式、用户消息与输入框。沿用单个可见最终回复的跟随范围，退出恢复原属性；本地验证透明状态、几何不变、滚动、草稿及恢复。各档复杂背景上的实际文字可读性仍需视觉确认。

当前布局修正（取代下文早期左侧阅读区方案）：用户实机反馈对话界面被挤到左侧，已删除 D6 对整个原生 main 的最大宽度限制及其跟随/回退逻辑。聊天和输入框沿用宿主布局；顶部黑边处理、材质、六档和视频保持。示例卡移除独立为 removeDiagnosticSample。回归检查改为验证宽窄窗口及任务替换后原生 main 不被收窄，长内容滚动和草稿保留。此前“左侧阅读区通过”只指本地行为符合旧设计，不代表用户认可其视觉效果；不再采用挤压对话区来避让人物。

长内容本地回归：在左侧阅读布局内加入 80 段构造回复和超宽代码行，通过正式 VisualState 的六档及 EX tokens 检查代码横向滚动、回复纵向滚动位置、输入草稿保留和布局不误触溢出回退。`node native-content.test.js` 通过。仅操作本地构造页，不发送真实消息；实际生成中的消息、真实宿主滚动行为和长期运行仍待实机验证。本轮未发现需要改动运行时代码的新问题。

日常使用收尾：D6 启用阅读布局时移除 D4 固定材质示例卡，避免进入任务后仍覆盖内容；D4 独立实验保留示例。补充本地任务 main 整体替换回归，验证旧 main 恢复、新 main 接续阅读布局且输入仍可用。阅读布局恢复时，若原 main 没有 style 属性且恢复后属性为空，则移除空属性，避免严格恢复检查误差；其他内联样式保留。用户反馈上一轮黑边/人物避让调整后“感觉好多了”；此反馈不替代生成中消息和长期运行的验收。

深色顶部黑边：将实机记录的 rgb(24,24,24) 到透明渐变加入精确匹配，仅处理唯一、至多 20px 高且满足装饰层条件的节点，其他渐变保留。D6 宽窗口阅读区：可用主区域至少 1000px 且原 main 延伸至右边缘时，将其最大宽度设为可用宽度的 60%（至少 640px），使聊天和输入框向左收窄、右侧留给人物；窄窗口恢复，检测到横向溢出则本次会话回退原布局。结束换肤恢复原 max-width。本地测试通过深浅渐变筛选、宽窄窗口、输入可用性、溢出回退、节点替换与清理；真实 Codex 的收窄效果和人物避让仍待视觉确认。

任务切换适配：跟随器在当前 theme 存在时重新定位唯一可见 editor 的最近圆角有底色表面，以及满足已验证几何范围的侧栏。新节点接上当前材质，已脱离文档的旧节点先恢复并释放记录；稳定节点不重复应用。复用原输入表面定位规则，歧义时不应用。本地浅色/深色起始样式下均验证节点替换、原按钮点击和恢复；未读取内容，未修改 Codex 全局主题。深色模式可作为优先视觉验收基准，但亮色档位及原生代码区的实机对比仍待确认；尚未覆盖所有页面、工具栏重挂载及生成中的消息。

EX 显示清晰度：播放视频时，视频承载层改为窗口原尺寸、无额外 transform/filter，视频自身由 104% 改为 100% cover，消除图片层与视频层叠加的扩边放大。视频暂停/回退时恢复原图片构图，不改正式素材。1280×720 本地测试确认视频源和显示矩形均为 1280×720，且父层 transform/filter 为 none；更大窗口或高像素密度屏幕仍受 720p 原片限制，不能视为真实超分辨率升级。

下一阶段：优先验证已完成任务的原生回复、代码块和输入区域在六档下的可读性与滚动恢复，再处理必要的视觉问题，最后统一验收持续运行、结束换肤和普通 Codex 恢复。新消息生成、任意页面导航和长期稳定性仍未验收，当前不能称为完整日常版。

EX 稳定背景：通过现有 exMotion.configure 关闭 D6 的 ambientEnabled 和 warmLightDemoEnabled，不再给整个视频容器叠加周期平移、缩放、亮度与色罩呼吸。原视频自身运动、首尾交叠和 EX 入退场保持。正式项目配置不改；本地回归检查跨两轮视频循环，背景 transform/filter 保持不变且无 CSS ambient 动画。

EX 循环接缝：原片长约 13.58 秒，首尾人物和头发位置略有差异，原生 loop 会硬切。D6 现使用同一原片的两个播放器，在最后约 0.7 秒交叠淡化；下层保持不透明，避免露出封面造成闪暗。两路均关闭原生 loop，退出 EX、页面隐藏或减少动态效果时一起暂停，退出实验时一起卸载。该办法缓和位置突跳，可能保留短暂重影，并非重新制作了首尾严格相同的视频。原 MP4、正式项目及 EX 入场曲线未修改；双播放器下的实机性能和接缝观感尚待复核。

### 154000 持续试用版实机基线

批次 runs/20260907-154000-c5118e94：GraphicsMode=DISABLE_GPU_REQUESTED，六档均访问、EX 视频发生播放、返回 L6、stopRequested=true，退出时无转场进行，全部页面/进程/端口/profile 清理和普通 Codex 恢复 PASS，FailureReason=NONE。本轮完成了持续试用入口的显式退出流程；不代表已经完成长期稳定性测试，也不能单凭这次成功证明 GPU 是此前唯一根因。

D6_SEQUENCE_PARTIAL 唯一待复核项为 nativeContentVisibleAtEnd；NativeContent=NOT_FOUND、candidateCount=0、switches=0。因此不把这次记为原生回复跟随实机通过，也不因没有回复而否定六档/视频/恢复成功。保留原报告和当前启动方式，无需为 PARTIAL 标签重复运行。下一阶段优先收集视觉与拖动手感反馈；原生回复接入另保留待验证状态。

用户已更正：103038 实验窗口自行关闭，并非手动关闭。此前“手动关闭导致失联”的结论撤回。已补传输及等待素材的控制台提示；原始失败报告保持不变。

退出排查找到两条同批次进程日志：21604 在 2026-09-07T02:22:53.513Z、34968 在 02:31:18.055Z 均记录 Recoverable Chromium child process gone，processType=GPU、reason=crashed、exitCode=-1。Windows 同时段 WER 记录为 Store 更新扫描失败，不能当作 Codex 崩溃证据。runner 在通信/页面清理失败后也会主动停止已验证的实验进程，因此“窗口消失”本身不能证明主进程崩溃。

D6 启动器现增加 -DisableGpu，仅向本次实验启动传入 --disable-gpu，结果记录 GraphicsMode=DISABLE_GPU_REQUESTED；普通 Codex 恢复仍使用空参数。用于验证图形路径相关性，不代表已确认窗口退出的完整根因。恢复原图形路径可在 PowerShell 直接运行 glass-lab.ps1 -SequenceReview（不加 -DisableGpu），不需要改系统设置。未自动运行真实 Codex。

103038 批次在 d6-load-poll 超时，说明分段发送及加载发起已返回，分段传输本身未解决 renderer 丢失问题。六档执行尚无成功证据；精确原因未知。大素材解码改用预分配字节数组与循环，避免 Uint8Array.from 字符迭代的中间分配，并在 Blob 创建后释放该项 base64 引用；这属于降低峰值内存的修正，不能宣称已证实或修复 renderer 崩溃。重连失败时新增 CLEANUP_TARGETS.json，只含目标类型、是否 app 页面、是否原调试端点，不含标题或页面路径。原始报告保持不变。

102216 批次：基础材质通过，约 22 MB 的整包在 d6-sequence-mount 阶段通信取消；随后原 renderer 身份匹配失败，未扩大清理对象，进程/端口/profile/普通 Codex 恢复通过。无法由此确认具体超时原因。现改为每段至多 262144 字符的传输、异步媒体初始化、独立就绪轮询；传输失败保留分段偏移量，媒体超时与上下文丢失单独报告。既有 renderer 身份门禁不放宽，不自动重放注入。sequence-transfer.test.js 用实际 PowerShell 函数和原始完整素材，在本地 Edge 中延迟 21 秒验证加载；该 HTTP 测试桥不等于真实 Codex CDP 验证。

入口 **run-d6-sequence.cmd**，一次查看 L1–L6、EX 原视频及返回原档。保存工作并完全退出普通 Codex后双击；无需先打开已有任务，原生 main、侧栏与输入区域就绪后直接加载。回复出现后由跟随器接管，无回复时保留 NOT_FOUND。材质加载后持续运行，不再限时 90 秒退出。右上角可点六档按钮或拖动滑杆（拖动中即时切档，连续拖动以最新档位为准）、进入 EX、返回原档；点击“结束换肤”后完成正在进行的转场，随后自动清理并恢复普通 Codex。启动器窗口须保持打开；全程不保存内容截图。

这是持续试用入口，仍以已完成任务为范围；尚未完成新消息生成、任意页面导航和客户端更新后的日常兼容验证。无需每次点遍六档才退出，未覆盖的项目如实保留 PARTIAL。已有 093235 实机证据仍有效，但不能替代新版结束按钮的实机验证。

094420 失败记录：D5 的启动门槛等待 90 秒仍无可见回复，D6 未开始；随后页面清理 CDP 超时，进程/端口/profile/普通 Codex 恢复 PASS。已将 D6 初始回复改为可选，D5 保持原有严格门槛；本地测试覆盖无回复启动和稍后挂载回复。清理样式改用同步计算样式验证，不再等待动画帧；没有证据将本次传输超时确认为后台动画帧停顿。原失败记录不改写，新启动流程尚待实机验证。

这批复用正式项目的 skin-config、visual-interpolation、skin-engine、pelican-transition、ex-motion 原代码；视频控制在实验目录 ex-video-loop.js 中由原 ex-video-background 接线扩展首尾交叠，通过私有命名空间和 Shadow DOM 接入已验证的视觉 root。build-sequence.js 读取原素材并打包 Blob，包含六张主线图、EX 封面与视频、鹈鹕遮挡素材，共九个文件；每轮保留素材 SHA256 清单和 bundle hash。没有改写原图、视频、450ms 主线曲线、1120ms 鹈鹕转场或1250ms EX 曲线，也不修改正式项目。

已接入选中的原生最终回复、已定位的输入表面及侧栏材质随档位变化；仍沿用 D5 单块跟随范围，不代表所有消息、多媒体嵌入或长期驻留已经完成。控件仅调整换肤，不改变模型、推理参数或计费。

本地检查 `node sequence.test.js` 验证六档单图稳定态、EX 原视频实际播放、L4/L6 往返、减少动态效果时封面回退及清理。runtime/local-d6-*.png 是本地构造页截图，不是 Codex 实机截图。旧 D4/D5 实机证据不作为 D6 通过依据。

新结果：runs/<批次>/D6_RESULT.md、D6_STRUCTURE.json、sequence.bundle.js.manifest.json。
- D6_SEQUENCE_READY_FOR_REVIEW：六档均访问、EX 视频发生播放、回到主线、原生内容及清理检查满足要求；视觉最终评价仍待用户。
- D6_SEQUENCE_PARTIAL：接入和恢复通过，但未完成全部交互，或结束时没有可见的受支持回复；后者单独列为 nativeContentVisibleAtEnd，不否定六档和视频证据。
- D6_SEQUENCE_FAILED：加载、接入或清理失败；保留错误原因，不能当作成功。

以下为 D4/D5 历史范围与证据，L1 限制只适用于旧入口。

### D6 093235 首次完整序列实机结果

批次 runs/20260907-093235-9d722f1a：六档全部访问、EX 原视频播放、返回 L6、单层稳定态与全部恢复/端口/profile 清理通过。最后内容结构为 NOT_FOUND、candidateCount 0、switches 2、previousTargetsRestored true；记录不能确定目标为何不可见，也不能据此认定跟随故障。

旧 runner 将这个结束条件当作 D5 的硬失败，所以原报告为 D6_SEQUENCE_FAILED。已修正 D6 分类：仅无可见回复且旧目标恢复成功时保留 PARTIAL 与明确待复核项；D5 仍要求最终回复可见，任何恢复、几何或前置失败仍 FAILED。PowerShell 5.1/7 的定义与分类回放检查通过。原报告保持原样，无须只为分类文字重跑。六档与视频的实机技术链路已经验证，视觉评价和长期驻留尚未完成。

状态：**L1 集中收尾候选已于 20260906-172326 实机通过全部材质与清理检查；视觉最终确认仍待用户。**

仅限真实 Codex + 锁定 L1。正式项目和 D3 目录保持原样。
复用 D3 的 Store activation、loopback CDP、Blob/object URL 和 main 透明化。
当前实验版本锁定 `26.901.5280.0`；该版本的实机兼容性由本轮实验确认，不能由静态检查推断。

## 运行

1. 保存工作，完全退出 Codex。
2. 双击本目录 `run-d4-lab.cmd`。只运行一次，实验期间不要另开 Codex 或输入内容。
3. 脚本完成清理并恢复普通 Codex后，读取本目录 `runs` 下最新批次。

每次使用时间戳和随机后缀的新目录，不删除旧截图或覆盖 D3：

```text
runs/<批次>/D4_RESULT.md
runs/<批次>/D4_STRUCTURE.json
runs/<批次>/d4-full-host.png
runs/<批次>/d4-debug-boundaries.png
```

截图仅在可确认空输入框、无消息、无可见对话框/终端/嵌入页面等条件下保存。
不读取正文、草稿内容、Cookie、storage、账户凭据或网络业务数据。
无法确认安全时标记 `SKIPPED_PRIVACY`，不会清除草稿或发送消息。

## 第一版范围

- main 延续 D3 透明状态；背景仍是原始 L1。
- 使用安装包核实的原生标题结构属性，应用暖白文字；宽窗口下与本地样例组成左侧信息列。
- 沿真实 editor 的祖先链定位最近的圆角、有底色表面，对 composer 局部玻璃化。
- 空会话里创建**一个带 LOCAL MATERIAL SAMPLE 标注的本地样例**。这不是原生 AI/user 消息接入成功的证据。
- 记录原生 turn/virtualized 容器数量，不读取正文、不重排消息。
- 调查 main 顶部窄条的几何与计算样式。仅清除唯一、无交互、无阴影和伪元素背景的浅色装饰节点，另支持实机确认的至多 20px 白色到透明渐变；其他渐变或多个候选保留为 `UNRESOLVED`。
- Sidebar、L2–L6、Pelican、EX 与正式 Visual Core 均不接入或改动。

材质起点：内容样例烟褐底 `.48` / blur `14px`，composer 暖黑底 `.76` / blur `14px`。
这些是实验参数，视觉定稿仍待审图。更改集中在 `glass.js`。

## 分类与恢复

- `D4_GLASS_READY_FOR_REVIEW`：四项实验及截图/清理检查满足脚本条件，**视觉仍待用户审图**。
- `D4_GLASS_PARTIAL`：底层接入与清理通过，但某处材质/白条未定位，或截图被跳过。查看 JSON 中各项原因。
- `D4_GLASS_FAILED`：前置验证、接入或清理失败。不要盲目重跑。

正常结束：还原被修改的局部 CSS 属性，移除样例、调试框、main override、L1 root，revoke object URL，
只清理以本次启动 PID/创建时间为根的已验证进程及后代，确认端口关闭，再删除本轮临时 profile 并恢复普通 Codex。
身份不明、PID 复用或端口未关闭时拒绝扩大清理范围，保留失败字段。
实验目录必须保留到结果核对完成。正常运行不需要手动修改客户端安装目录或配置。

## 本地检查（不会启动或停止 Codex）

```powershell
node glass.test.js
powershell.exe -NoProfile -File .\check.ps1
pwsh.exe -NoProfile -File .\check.ps1
```

`glass.test.js` 使用机器上已有的 Playwright 和 headless Edge，对**本地构造的 DOM**检查
真实 L1 Blob 加载、材质应用、重复调用、隐私门禁、歧义保留和完整恢复。
`check.ps1` 只加载函数定义，校验 BOM、解析、Store 身份、L1 hash、clean HEAD、C# 编译及模拟进程清理。
两者都不能替代真实 Codex 实验，且不生成伪装成实机结果的截图。

D3 来源脚本 SHA-256：`4CAA75845EAD701A73216EA10776614C772570FF4B92A692FCB9089C2FBF8B2D`。
每次实机结果另记录当前 runner 和 glass.js 的 SHA-256，便于对应代码与证据。

## 首次实机 PARTIAL 后修正

标题改用安装包源码核实的 `div.heading-xl[data-feature="game-source"]`，不再假定为 h1。
顶部白条支持首轮证据中的 16px 白色渐变，并恢复原有 background-image。
输入框上方独立白栏已补局部材质：从 Store 26.901.5280.0 的 composer-utility-bar-1767a716decd.js 追到 app-primary 中的 Vsr / s3.Item，确认 home + controls + rail-item 属性；CSS 的 ComposerHomeUtilityBar 使用独立背景色。运行时还要求唯一、可见、非 inert、紧贴 composer 且宽度匹配。歧义、警告栏和隐藏栏不修改。
D4_STRUCTURE.json 的 composerContext 记录候选及应用后计算样式；样例避开工具栏。恢复时还原所有修改的 CSS 属性。该项 APPLIED 是 READY_FOR_REVIEW 的必要条件。
本地 Edge 已检查点击、恢复、重复候选、警告栏、隐藏栏、宽度异常及缺少标记；本地测试不代表实机视觉通过。

## 033534 实机反馈

标题 MATCHED、顶部渐变清除、composer APPLIED、全部清理 PASS；工具栏 UNRESOLVED，样例 SKIPPED_INSUFFICIENT_SPACE。
本轮修正允许工具栏两侧各 0–24px 对称内缩（截图约 13px），保留原生属性、唯一性与高度限制。样式提交后重新测量 composer；样例未出现的精确原因仍需下一轮 layout 数值确认。JSON 现在保留全部工具栏锚点的 accepted 标志和样例可用高度，不再只输出筛选后的零候选。
本地回归覆盖内缩工具栏和下一帧 composer 位置变化；尚未重新实机验证。

## 034204 实机验证通过，待视觉评审

证据：runs/20260906-034204-17aea293/D4_RESULT.md 与两张实机截图。分类 D4_GLASS_READY_FOR_REVIEW，GlassLab MATERIAL_APPLIED；标题、顶部渐变、工具栏、输入框与本地样例均生效，清理全部 PASS。
真实工具栏为 710×42，两侧内缩 13px。输入框表面顶部 573.2px，外层 root 顶部 535.2px：此前使用 root 测量会少算 38px；改为表面后样例可用高度 140.6px，大于所需 118px。
当前 glass.js SHA256：013D5ECA068FE63008FE37AB3AA58CEE16B454A60814741E75B31323E4D5DDAB。
视觉待评审：标题与原生图标仍叠在人物区域；侧栏文字在纹理背景上对比偏低；样例是实验卡片而非原生消息。下一阶段应先明确信息布局和侧栏对比度，再扩展级别或接入消息。VisualAcceptance 保留 PENDING_USER_REVIEW，本轮不修改正式项目或原插图。

## L1 左侧布局候选（尚未实机验证）

在 main 宽度至少 800px 且空会话安全检查通过时，原生标题改为 24px、宽度至多 400px，视觉位置移到 main 左侧 28px、顶部 150px；本地样例采用同宽并在标题下方留 18px。窄窗口保留原生标题布局。标题 DOM 与按钮事件不替换，修改的 CSS 由既有 cleanup 逐项恢复。
本地 Edge 在 1280、1440、900px 检查左列边界、样例间距、标题按钮点击与 translate 恢复。原生图标和侧栏本轮未调整。已通过的 034204 实机证据保留，不能作为这个新版的视觉通过证据。

## 035449 工具栏延迟挂载

左侧标题与样例均实机生效，GlassLab MATERIAL_APPLIED，清理 PASS。composerContext 在检查时零锚点，而随后实机截图出现白色工具栏；补充最多 1500ms、每 100ms 一次的结构锚点等待。等待后重新测量输入框表面，原有唯一性与几何限制保留；超时仍 UNRESOLVED。JSON 记录 contextWaitMs。新增延迟挂载回归与恢复检查，新版尚待实机验证。

## L1 集中收尾候选

本批合并：工具栏延迟挂载等待、左侧标题/样例、原生 home-icon 移至标题上方、侧栏滚动区暖浅玻璃、PendingMaterialChecks 汇总。home-icon 保留原生旋转/悬停事件，单独使用 translate；侧栏仅修改背景及 blur，保留文字色和结构。任何修改仍由同一 cleanup 精确恢复。
宿主与窗口限制：仍只支持当前锁定 Store 版本和 L1，宽 main（至少 800px）为左列验收范围；窄窗口保留原生标题与图标位置。未满足所有材质检查时保持 PARTIAL，不把静态测试等同实机通过。
统一验收一次检查：标题与图标是否避开人物、侧栏文字是否清楚、工具栏是否消除白底、样例是否有足够间距、输入与原生按钮是否正常、恢复是否全部 PASS。后续问题以这次完整结果集中处理，不再按单项反复要求重跑。
未进入本批：原生消息材质、L2–L6/EX 接入、长期驻留与自动更新适配。这些不是当前 D4 完成条件。

## 172326 集中验收结论

证据批次 runs/20260906-172326-8f1b824e：D4_GLASS_READY_FOR_REVIEW，PendingMaterialChecks NONE，GlassLab MATERIAL_APPLIED。截图、样式恢复、root/object URL 清理、端口关闭、临时 profile 删除及普通 Codex 恢复全部 PASS。glass.js 当前哈希与该实机结果一致：A1D706281C5457E16D5302B476D3E82768A84F2E117F055FDE63B0703D72DD0B。

审图：标题、原生图标及样例已移离人物面部，工具栏白底消除。侧栏可读性改善，但浅色矩形与顶部/底部透明区域形成明显断层；输入框占位提示偏暗。以上保留为下一批视觉打磨项，不改变本次证据或冒充用户审美通过。

D4 仍是空会话单样例实验；原生长消息、代码与滚动/窗口变化持续适配尚未验证。下一阶段优先选择一种原生内容容器接入与恢复验证，再考虑多等级动态接入。本次不再要求重复运行同版。

## D5：一个真实最终助手回复（固定单块已实机通过，跟随版待统一验收）

入口 `run-d5-content.cmd`，复用同一个 runner 的 `-ContentReview` 模式。D4 入口保持原有行为。

1. 保存并完全退出普通 Codex，再双击 D5 入口。
2. 实验 Codex 打开后，90 秒内自行选择一个已有的、已完成的本地任务，让最终助手回复可见。不发送新消息。
3. 脚本在 20 秒观察期内跟随最后一个可见的受支持回复块；可以滚动已有任务，结束时保留一个最终回复可见。随后自动恢复和退出实验。此模式始终禁用截图。
4. 结果是 runs/<批次>/D5_RESULT.md 与 D5_STRUCTURE.json；成功分类 D5_CONTENT_APPLIED_PENDING_REVIEW。不以 D4 的首页标题/样例检查评判 D5。

来源：Store 26.901.5280.0 的 subagent-activity-chip-group-7098f4d5c724.js，sD 使用 data-local-conversation-final-assistant=true 标记 assistant-item。仅在 main 与原生 turn 内选取，排除 composer、隐藏/inert、iframe/canvas/MCP 应用及编辑器，不读取正文或标记值中的任务 ID。

材质只改背景、模糊、圆角、内阴影及局部文字变量；不改 padding、尺寸、正文 DOM、代码着色或事件。记录结构路径、几何与计算样式；不记录正文。单次应用 API 保持同一目标；跟随模式会先恢复旧节点再选择当前可见块，始终只有一个块被修改。cleanup 同时恢复已脱离文档的原节点。

本地测试：node native-content.test.js。覆盖单块选取、几何不变、代码颜色、按钮、截图门禁、重复调用、隐藏目标及卸载恢复。滚动跟随与节点替换已补本地验证，尚待实机；真实流式生成、嵌入应用、多块同时换肤不在本阶段支持范围。正式项目、资产和动态引擎仍未修改。

## D5 175015 首次实机诊断

NativeContent APPLIED，选中一个真实最终助手回复，前后 736×301.55px 不变。随后 l1 注入结果返回前发生通信取消；原记录缺少 send/receive 阶段，不能进一步归因。WebSocket Aborted 导致页面内 cleanup 无法验证，相关 FAIL 保留；验证过的进程/端口/profile 清理及普通 Codex 恢复 PASS。

通信等待由每次 ReceiveAsync 5 秒调整为有总截止时间的 20 秒；异常输出 stage/id/socket。中断后仅清理可重连同一验证进程与 renderer，不重放注入。cdp-transport.test.js 使用本地假服务器测试延迟 6 秒响应及 Aborted 阶段诊断，不启动 Codex。新版实机待验证，未将原失败记录改成通过。

## D5 183034 实机通过

证据批次 runs/20260906-183034-6582370e：D5_CONTENT_APPLIED_PENDING_REVIEW，真实最终助手回复 APPLIED，736×170px 几何不变；L1 背景、main 透明与全部清理 PASS，CleanupReconnect NOT_NEEDED，截图按设计跳过。视觉确认仍待用户，本轮未读取内容正文或生成内容截图。
原记录中的 headline/composerContext/contentSample/homeIcon 是首页专属检查，不适用于 D5 任务页；报告显示已修正，不修改原始实机证据，也不要求为报告文字重跑。D5 新报告 GlassLab 为 NATIVE_CONTENT_APPLIED，待检查项仅保留适用项。

## D5 单块跟随候选（未实机验证）

在已有本地任务中选中回复后，新增 20 秒滚动观察阶段；同一时刻仍只处理最后一个可见最终助手回复。滚动、窗口 resize、DOM 替换/隐藏/文本更新触发浏览器 rAF 合并刷新；不读取文本变更值。目标改变时先恢复旧节点，删除对应恢复记录，再处理新节点。观察结束请保留一个最终助手回复可见。

初始 applyNativeContent 保留单次锁定行为；观察阶段使用 startNativeContentTracking / refreshNativeContent。cleanup 先 disconnect observer、取消 rAF、移除 scroll/resize listener，再恢复样式。D5_STRUCTURE.json 增加 switches 和 previousTargetsRestored；没有切换仅代表该轮未触发切换，不能据此声称滚动已实机验证。

本地回归覆盖滚动换目标、脱离文档节点恢复、新节点接管、隐藏/显示、清理后不再响应。未新增消息、未打开任务、未启动实机实验。原生流式输出的后端生成仍未实机验证；此次仅以本地 DOM 更新验证跟随机制。

## 20260907 跟随版集中补齐

回复可见范围同时考虑窗口和祖先滚动区裁剪；不再选中仍处于窗口坐标内、却被内部滚动区裁掉的块。新增祖先 style/class/hidden 变化监听，无须滚动即可恢复隐藏目标并接管可见块。沿用现有 MutationObserver 与 rAF，稳定目标不重复写样式，自身样式通知在额外一次刷新后停止。

本地回归先复现“祖先 display:none 后旧节点仍有材质”，修复后覆盖 style/class/hidden 隐藏与恢复、样式写入停止、cleanup 后停止跟随。上述修改与之前的滚动、节点替换一起等待一次 D5 实机验收；183034 批次只证明固定单块成功，不能证明新版跟随成功。无须逐项重跑，仍使用 run-d5-content.cmd 的 20 秒观察期，不保存内容截图。
