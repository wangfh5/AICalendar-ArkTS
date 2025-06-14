# AI 日程生成器

使用自然语言生成日程, 接入到华为日历中. 使用ArkTS语言原生开发的简单应用. 

## 功能
- 在华为日历中新建日历账户 (名称为`AI日历`). 参考: [日历账户管理-Calendar Kit（日历服务）-应用服务 - 华为HarmonyOS开发者](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/calendarmanager-calendar-developer)
- 用户输入自然语言, 点击`AI解析`后调用大模型来提取关键信息. 
- 点击`创建日程`, 将日程信息写入到日历账户之中. 参考: [日程管理-Calendar Kit（日历服务）-应用服务 - 华为HarmonyOS开发者](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/calendarmanager-event-developer). 

## 模型配置
支持所有兼容OpenAI API的模型服务. 默认为 DeepSeek 官方的 deepseek-chat 模型. 
初次使用, 在`配置`中配置API key, 以及按需配置 Base URL和模型ID. 

## 相关链接
- [wangfh5/AICalendar: 使用自然语言生成.ics文件](https://github.com/wangfh5/AICalendar): Python GUI应用
- [wangfh5/AICalendar: 使用自然语言生成.ics文件](https://github.com/wangfh5/AICalendar): Kotlin 安卓应用