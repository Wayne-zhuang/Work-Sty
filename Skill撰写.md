以下是为您整理的 **Claude Code Skills 实操教学指南** 的 Markdown 版本，您可以直接复制使用。

---

# **Claude Code Skills 实操教学指南**

### **1. 环境准备：安装 Claude**
在开始编写 Skill 之前，请确保您已完成 Claude 的安装与环境配置。
*   **安装教程：** [点击查看详细安装步骤](https://alidocs.dingtalk.com/i/nodes/QG53mjyd80yErAqlFbPvrxpYW6zbX04v?dontjump=true&utm_scene=team_space&utm_medium=main_vertical&utm_source=search)（此链接为外部资源，请根据指引操作）。

---

### **2. 认识 Skills 的目录结构**
每个 Skill 都必须是一个独立的目录，且 **`SKILL.md` 文件是其必需的入口点**。

*   **项目级（仅当前项目有效）**：`.claude/skills/<skill-name>/SKILL.md`
*   **个人级（所有项目通用）**：`~/.claude/skills/<skill-name>/SKILL.md`

**目录示例：**
```text
.claude/skills/my-helper/
├── SKILL.md          # 核心说明文档（必需）
├── template.json     # 可选：支持文件或模板
└── script.py         # 可选：辅助脚本
```
**优先级规则**：当存在同名 Skill 时，优先级顺序为：**企业 > 个人 > 项目**。

---

### **3. 撰写规范：创建你的第一个 Skill**

编写 Skill 的核心在于 `SKILL.md` 顶部的配置头。请务必遵守以下格式要求：

#### **第一步：定义 YAML 配置头 (Frontmatter)**
**注意**：`name:` 和 `description:` 关键字必须是英文。

```markdown
---
name: explain-logic
description: Explains complex code logic using visual diagrams and analogies.
disable-model-invocation: false
---
```
*   **name**: Skill 的显示名称（仅限小写字母、数字和连字符）。
*   **description**: **关键字段**。Claude 会根据这段描述判断何时自动加载此 Skill。
*   **disable-model-invocation**: 设置为 `true` 则防止 Claude 自动触发，仅允许用户手动调用（适用于部署等敏感操作）。

#### **第二步：编写指令内容**
在配置头下方，使用 Markdown 编写具体的指令或参考资料。

---

### **4. 核心功能实操**

#### **使用动态变量处理参数**
你可以通过 `$ARGUMENTS`（或简写 `$0`, `$1`）来接收调用时传递的参数。
```markdown
# 示例：快速修复 Issue
---
name: fix-issue
description: Fixes a specific GitHub issue by number.
---
请根据我们的编码标准修复 GitHub 上的第 $0 号问题。
```
**调用方式**：在终端输入 `/fix-issue 123`，Claude 就会收到包含“123”的指令。

#### **注入动态 Shell 命令输出**
使用 `!command`` 语法可以在发送提示词前运行脚本，并将结果注入。
```markdown
# 示例：总结 Pull Request
---
name: summarize-pr
description: Summarizes the current PR using git data.
---
当前的 PR 差异如下：
!git diff main..HEAD`
请根据以上内容生成摘要。
```
*   **注意**：这是在 Claude 看到提示词之前的预处理阶段执行的。

---

### **5. 如何调用与调试**

*   **自动触发**：只要你的提问与 `description` 中的描述相关，Claude 就会自动应用该 Skill。
*   **手动触发**：在聊天框输入 `/` 即可看到可用 Skill 列表并选择运行。
*   **故障排除**：
    *   如果 Skill 未触发，请检查 `description` 是否包含相关的关键字。
    *   使用 `/context` 命令可以检查当前已加载的 Skill 及其占用的上下文配额。

---

**提示**：建议将 `SKILL.md` 保持在 **500 行以下**。如果有大量参考资料，请将其放在同目录下的独立文件中并在 `SKILL.md` 中引用。  
  

# skill上传

登陆[http://192.168.110.218:3201/skills](http://192.168.110.218:3201/skills)

点击添加技能

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/99a2bc0b-b092-4f77-a4e5-f9e138105f72.png)

点击上传

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/1f3b87b6-277a-4df4-b03f-a2d5b378035e.png)

1.  将你本地写好的SKILL.md文件中name内容填入Skill标题，
    
2.  将你本地写好的SKILL.md文件中description内容填入描述
    
3.  点击下滑箭头选择对应的分类，没找到就选其他
    
4.  将你写好的技能压缩上传
    
5.  最后点击保存
    

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/b6ea0579-0318-489c-9987-971309fd535d.png)

点击提交审核

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/984fa35e-512e-4ac5-b07f-b66f4d908d21.png)

等管理员审核通过即可

如果审核通过，你的技能又更新需求，点击更新

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/72579223-5661-4b25-ac28-4a3807711f25.png)

1.  如有更新将你本地写好的SKILL.md文件中name内容填入Skill标题，
    
2.  如果有更新将你本地写好的SKILL.md文件中description内容填入描述
    
3.  将你更新好的技能压缩上传
    
4.  版本号必须更新
    
5.  最后点击更新
    

![image.png](https://alidocs.oss-cn-zhangjiakou.aliyuncs.com/res/2M9qP5j5VWAXJO01/img/2b14a86c-2bee-4228-ac11-946646fb04c2.png)