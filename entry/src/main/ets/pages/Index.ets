// Index.ets - AI智能日程创建主页
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { calendarManager } from '@kit.CalendarKit';
import { promptAction } from '@kit.ArkUI';
import { calendarMgr, mContext, AITextParser, AIConfig, ParsedEventData } from '../entryability/EntryAbility';

@Entry
@Component
struct Index {
  @State message: string = '🤖 AI智能日程助手'
  
  // 日历相关状态
  @State calendar: calendarManager.Calendar | undefined = undefined
  
  // 传统日程表单状态
  @State eventTitle: string = ''
  @State eventDescription: string = ''
  @State eventLocation: string = ''
  @State selectedEventType: number = 0
  @State reminderMinutes: number = 10
  @State isRecurring: boolean = false
  @State selectedFrequency: number = 0
  @State recurringCount: number = 1
  
  // 时间相关状态
  @State startDate: string = ''
  @State startTime: string = ''
  @State endDate: string = ''
  @State endTime: string = ''
  
  // AI解析相关状态
  @State aiInputText: string = ''
  @State showAIConfig: boolean = false
  @State apiKey: string = ''
  @State baseUrl: string = 'https://api.deepseek.com'
  @State model: string = 'deepseek-chat'
  @State isAIParsing: boolean = false
  @State showTraditionalForm: boolean = false
  
  // 选项数组
  private eventTypes: string[] = ['普通日程', '重要日程']

  // 初始化日历账户
  async initCalendar() {
    try {
      if (!calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化，请重启应用',
          duration: 2000
        });
        return;
      }
      
      // 获取或创建日历账户
      const calendarAccount: calendarManager.CalendarAccount = {
        name: 'MyCalendar',
        type: calendarManager.CalendarType.LOCAL,
        displayName: '我的日历账户'
      };
      
      try {
        this.calendar = await calendarMgr.getCalendar(calendarAccount);
        console.info('Calendar account already exists');
      } catch (getError) {
        this.calendar = await calendarMgr.createCalendar(calendarAccount);
        const config: calendarManager.CalendarConfig = {
          enableReminder: true,
          color: '#4CAF50'
        };
        await this.calendar.setConfig(config);
        console.info('Calendar account created successfully');
      }
      
      console.info('Calendar initialized successfully');
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to initialize calendar. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '初始化日历失败: ' + message,
        duration: 2000
      });
    }
  }

  // 创建日程
  async createEvent() {
    try {
      if (!this.calendar) {
        await this.initCalendar();
      }
      
      if (!this.calendar) {
        promptAction.showToast({
          message: '日历未初始化',
          duration: 2000
        });
        return;
      }

      // 验证必填字段
      if (!this.eventTitle.trim()) {
        promptAction.showToast({
          message: '请输入日程标题',
          duration: 2000
        });
        return;
      }

      // 解析时间
      const now = new Date();
      const startDateTime = this.parseDateTime(this.startDate, this.startTime) || now.getTime();
      const endDateTime = this.parseDateTime(this.endDate, this.endTime) || (startDateTime + 60 * 60 * 1000);

      if (endDateTime <= startDateTime) {
        promptAction.showToast({
          message: '结束时间必须晚于开始时间',
          duration: 2000
        });
        return;
      }

      // 构建日程对象
      let eventType = calendarManager.EventType.NORMAL;
      if (this.selectedEventType === 1) {
        eventType = calendarManager.EventType.IMPORTANT;
      }

      let reminderArray: number[] = [];
      if (this.reminderMinutes > 0) {
        reminderArray = [this.reminderMinutes];
      }

      const event: calendarManager.Event = {
        title: this.eventTitle,
        description: this.eventDescription,
        type: eventType,
        startTime: startDateTime,
        endTime: endDateTime,
        reminderTime: reminderArray
      };

      // 如果有地点信息，添加location字段
      if (this.eventLocation.trim()) {
        const locationInfo: calendarManager.Location = {
          location: this.eventLocation,
          latitude: 0,
          longitude: 0
        };
        event.location = locationInfo;
      }

      // 添加重复规则（如果启用）
      if (this.isRecurring && this.recurringCount > 0) {
        let frequency = calendarManager.RecurrenceFrequency.DAILY;
        if (this.selectedFrequency === 1) {
          frequency = calendarManager.RecurrenceFrequency.WEEKLY;
        } else if (this.selectedFrequency === 2) {
          frequency = calendarManager.RecurrenceFrequency.MONTHLY;
        } else if (this.selectedFrequency === 3) {
          frequency = calendarManager.RecurrenceFrequency.YEARLY;
        }
        
        event.recurrenceRule = {
          recurrenceFrequency: frequency,
          count: this.recurringCount,
          interval: 1
        };
      }

      // 创建日程
      const eventId = await this.calendar.addEvent(event);
      
      promptAction.showToast({
        message: `日程创建成功！ID: ${eventId}`,
        duration: 2000
      });
      
      // 清空表单
      this.clearForm();
      
      console.info(`Event created successfully, ID: ${eventId}`);
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to create event. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '创建日程失败: ' + message,
        duration: 2000
      });
    }
  }

  // 解析日期时间字符串
  parseDateTime(dateStr: string, timeStr: string): number | null {
    if (!dateStr || !timeStr) return null;
    
    try {
      const dateTimeStr = `${dateStr}T${timeStr}:00`;
      const dateTime = new Date(dateTimeStr);
      return dateTime.getTime();
    } catch (error) {
      console.error('解析时间失败:', error);
      return null;
    }
  }

  // 页面初始化时加载AI配置
  async aboutToAppear() {
    await this.loadAIConfig();
  }

  // 加载AI配置
  async loadAIConfig() {
    if (mContext) {
      const config = await AIConfig.getConfig(mContext);
      this.apiKey = config.apiKey;
      this.baseUrl = config.baseUrl;
      this.model = config.model;
    }
  }

  // 保存AI配置
  async saveAIConfig() {
    if (mContext) {
      await AIConfig.saveConfig(mContext, this.apiKey, this.baseUrl, this.model);
      this.showAIConfig = false;
      promptAction.showToast({
        message: 'AI配置保存成功',
        duration: 2000
      });
    }
  }

  // AI解析自然语言
  async parseWithAI() {
    if (!this.aiInputText.trim()) {
      promptAction.showToast({
        message: '请输入日程描述',
        duration: 2000
      });
      return;
    }

    if (!this.apiKey.trim()) {
      promptAction.showToast({
        message: '请先配置API Key',
        duration: 2000
      });
      this.showAIConfig = true;
      return;
    }

    this.isAIParsing = true;

    try {
      const parser = new AITextParser(this.apiKey, this.baseUrl, this.model);
      const parsedData = await parser.parseText(this.aiInputText);
      
      // 将解析结果填入表单
      this.fillFormWithParsedData(parsedData);
      
      promptAction.showToast({
        message: 'AI解析成功！请检查并确认信息',
        duration: 2000
      });
      
      // 显示传统表单供用户确认
      this.showTraditionalForm = true;
      
    } catch (error) {
      console.error('AI解析失败:', error);
      promptAction.showToast({
        message: `AI解析失败: ${error.message}`,
        duration: 3000
      });
    } finally {
      this.isAIParsing = false;
    }
  }

  // 将AI解析结果填入表单
  fillFormWithParsedData(data: ParsedEventData) {
    this.eventTitle = data.summary;
    this.eventDescription = data.description || '';
    this.eventLocation = data.location || '';
    this.reminderMinutes = data.reminderMinutes;
    this.isRecurring = data.isRecurring;
    
    // 解析时间
    if (data.startTime) {
      const startDateTime = new Date(data.startTime);
      this.startDate = startDateTime.toISOString().split('T')[0];
      this.startTime = startDateTime.toTimeString().split(' ')[0].substring(0, 5);
    }
    
    if (data.endTime) {
      const endDateTime = new Date(data.endTime);
      this.endDate = endDateTime.toISOString().split('T')[0];
      this.endTime = endDateTime.toTimeString().split(' ')[0].substring(0, 5);
    }
    
    // 设置重复频率
    if (data.isRecurring && data.recurrenceFrequency) {
      switch (data.recurrenceFrequency) {
        case 'daily':
          this.selectedFrequency = 0;
          break;
        case 'weekly':
          this.selectedFrequency = 1;
          break;
        case 'monthly':
          this.selectedFrequency = 2;
          break;
        case 'yearly':
          this.selectedFrequency = 3;
          break;
      }
      this.recurringCount = data.recurrenceCount || 1;
    }
  }

  // 清空表单
  clearForm() {
    this.eventTitle = '';
    this.eventDescription = '';
    this.eventLocation = '';
    this.selectedEventType = 0;
    this.reminderMinutes = 10;
    this.isRecurring = false;
    this.selectedFrequency = 0;
    this.recurringCount = 1;
    this.startDate = '';
    this.startTime = '';
    this.endDate = '';
    this.endTime = '';
    this.aiInputText = '';
    this.showTraditionalForm = false;
  }

  build() {
    Stack() {
      // 主内容
      Scroll() {
        Column() {
          // 标题和日历管理按钮
          Row() {
            Text(this.message)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
            
            Blank()
            
            Button() {
              Text(' 日历账户管理 ')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .type(ButtonType.Capsule)
            .backgroundColor('#9C27B0')
            .height(40)
            .onClick(() => {
              router.pushUrl({ url: 'pages/CalendarManager' }).then(() => {
                console.info('Succeeded in jumping to calendar manager page.')
              }).catch((err: BusinessError) => {
                console.error(`Failed to jump to calendar manager page. Code is ${err.code}, message is ${err.message}`)
              })
            })
          }
          .width('100%')
          .margin({ bottom: 20 })
          
          // AI解析区域
          if (!this.showTraditionalForm) {
            Column() {
              Text('只需用自然语言描述您的日程，AI将自动为您解析并创建')
                .fontSize(16)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .margin({ bottom: 16 })
                .textAlign(TextAlign.Center)
              
              // AI输入框
              TextArea({ 
                placeholder: '例如：明天下午3点在会议室开产品评审会，提前30分钟提醒我',
                text: this.aiInputText
              })
                .onChange((value: string) => {
                  this.aiInputText = value;
                })
                .width('100%')
                .height(120)
                .margin({ bottom: 16 })
              
              // 操作按钮行
              Row() {
                Button() {
                  if (this.isAIParsing) {
                    LoadingProgress()
                      .width(20)
                      .height(20)
                      .color(Color.White)
                  } else {
                    Text('🚀 AI解析')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#4CAF50')
                .width('45%')
                .height(55)
                .enabled(!this.isAIParsing)
                .onClick(() => {
                  this.parseWithAI();
                })

                Button() {
                  Text('⚙️ 配置')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#FF9800')
                .width('25%')
                .height(55)
                .onClick(() => {
                  this.showAIConfig = true;
                })

                Button() {
                  Text('📝 手动')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#2196F3')
                .width('25%')
                .height(55)
                .onClick(() => {
                  this.showTraditionalForm = true;
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 20 })
            }
            .width('100%')
            .padding(20)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .borderRadius(12)
            .margin({ bottom: 20 })
          }

          // 传统表单区域
          if (this.showTraditionalForm) {
            Column() {
              // 标题和返回按钮行
              Row() {
                Text('📋 日程详情确认')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                
                Blank()
                
                Button() {
                  Text('返回AI')
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                }
                .type(ButtonType.Normal)
                .backgroundColor('transparent')
                .onClick(() => {
                  this.showTraditionalForm = false;
                })
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 操作按钮区域 - 在最上面
              Row() {
                Button() {
                  Text('✅ 创建日程')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#4CAF50')
                .width('48%')
                .height(45)
                .onClick(() => {
                  this.createEvent();
                })

                Button() {
                  Text('🗑️ 清空表单')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#FF9800')
                .width('48%')
                .height(45)
                .onClick(() => {
                  this.clearForm();
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 20 })
              
              // 日程标题输入
              Column() {
                Text('📝 日程标题 *')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                TextInput({ placeholder: '请输入日程标题', text: this.eventTitle })
                  .onChange((value: string) => {
                    this.eventTitle = value;
                  })
                  .width('100%')
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 日程描述输入
              Column() {
                Text('📄 日程描述')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                TextArea({ placeholder: '请输入日程描述', text: this.eventDescription })
                  .onChange((value: string) => {
                    this.eventDescription = value;
                  })
                  .width('100%')
                  .height(80)
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 日程地点输入
              Column() {
                Text('📍 日程地点')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                TextInput({ placeholder: '请输入日程地点', text: this.eventLocation })
                  .onChange((value: string) => {
                    this.eventLocation = value;
                  })
                  .width('100%')
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 开始时间
              Column() {
                Text('🕐 开始时间')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                Row() {
                  TextInput({ placeholder: 'YYYY-MM-DD', text: this.startDate })
                    .type(InputType.Normal)
                    .onChange((value: string) => {
                      this.startDate = value;
                    })
                    .width('48%')
                  
                  TextInput({ placeholder: 'HH:MM', text: this.startTime })
                    .type(InputType.Normal)
                    .onChange((value: string) => {
                      this.startTime = value;
                    })
                    .width('48%')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 结束时间
              Column() {
                Text('🕑 结束时间')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                Row() {
                  TextInput({ placeholder: 'YYYY-MM-DD', text: this.endDate })
                    .type(InputType.Normal)
                    .onChange((value: string) => {
                      this.endDate = value;
                    })
                    .width('48%')
                  
                  TextInput({ placeholder: 'HH:MM', text: this.endTime })
                    .type(InputType.Normal)
                    .onChange((value: string) => {
                      this.endTime = value;
                    })
                    .width('48%')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 日程类型选择
              Column() {
                Text('🏷️ 日程类型')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                Row() {
                  ForEach(this.eventTypes, (type: string, index: number) => {
                    Row() {
                      Radio({ value: `type_${index}`, group: 'eventType' })
                        .checked(this.selectedEventType === index)
                        .onChange((isChecked: boolean) => {
                          if (isChecked) {
                            this.selectedEventType = index;
                          }
                        })
                      
                      Text(type)
                        .fontSize(14)
                        .margin({ left: 8 })
                    }
                    .margin({ right: 20 })
                  })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ bottom: 16 })

              // 提醒时间选择
              Column() {
                Text('⏰ 提醒时间')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })
                
                Row() {
                  ForEach([0, 5, 10, 15, 30, 60], (minutes: number, index: number) => {
                    Row() {
                      Radio({ value: `reminder_${index}`, group: 'reminderTime' })
                        .checked(this.reminderMinutes === minutes)
                        .onChange((isChecked: boolean) => {
                          if (isChecked) {
                            this.reminderMinutes = minutes;
                          }
                        })
                      
                      Text(minutes === 0 ? '不提醒' : `提前${minutes}分钟`)
                        .fontSize(12)
                        .margin({ left: 4 })
                    }
                    .margin({ right: 10 })
                  })
                }
                .width('100%')
              }
              .width('100%')
              .margin({ bottom: 16 })

              // 重复设置
              Column() {
                Row() {
                  Checkbox()
                    .select(this.isRecurring)
                    .onChange((value: boolean) => {
                      this.isRecurring = value;
                    })
                  
                  Text('🔄 重复日程')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .margin({ left: 8 })
                }
                .alignItems(VerticalAlign.Center)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

                if (this.isRecurring) {
                  Column() {
                    Text('重复频率')
                      .fontSize(14)
                      .alignSelf(ItemAlign.Start)
                      .margin({ bottom: 8 })
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    
                    Row() {
                      ForEach(['每天', '每周', '每月', '每年'], (freq: string, index: number) => {
                        Row() {
                          Radio({ value: `freq_${index}`, group: 'frequency' })
                            .checked(this.selectedFrequency === index)
                            .onChange((isChecked: boolean) => {
                              if (isChecked) {
                                this.selectedFrequency = index;
                              }
                            })
                          
                          Text(freq)
                            .fontSize(14)
                            .margin({ left: 8 })
                            .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        }
                        .margin({ right: 20 })
                      })
                    }
                    .width('100%')
                    .margin({ bottom: 8 })

                    Text('重复次数')
                      .fontSize(14)
                      .alignSelf(ItemAlign.Start)
                      .margin({ bottom: 8 })
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    
                    TextInput({ placeholder: '请输入重复次数', text: this.recurringCount.toString() })
                      .type(InputType.Number)
                      .onChange((value: string) => {
                        const num = parseInt(value);
                        if (!isNaN(num) && num > 0) {
                          this.recurringCount = num;
                        }
                      })
                      .width('100%')
                  }
                  .padding(16)
                  .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                  .borderRadius(8)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ bottom: 20 })
            }
            .width('100%')
            .padding(20)
          }
        }
        .width('100%')
        .padding(20)
      }
      .height('100%')
      .width('100%')

      // AI配置弹窗
      if (this.showAIConfig) {
        Column() {
          Blank()
          
          // 配置面板
          Column() {
            Text('🤖 AI配置')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })
            
            // API Key输入
            Column() {
              Text('API Key *')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              TextInput({ 
                placeholder: '请输入您的API Key',
                text: this.apiKey
              })
                .type(InputType.Password)
                .onChange((value: string) => {
                  this.apiKey = value;
                })
                .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // Base URL输入
            Column() {
              Text('API地址')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              TextInput({ 
                placeholder: 'https://api.deepseek.com',
                text: this.baseUrl
              })
                .onChange((value: string) => {
                  this.baseUrl = value;
                })
                .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 模型选择
            Column() {
              Text('模型')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              TextInput({ 
                placeholder: 'deepseek-chat',
                text: this.model
              })
                .onChange((value: string) => {
                  this.model = value;
                })
                .width('100%')
            }
            .width('100%')
            .margin({ bottom: 20 })
            
            // 按钮行
            Row() {
              Button() {
                Text('取消')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
              }
              .type(ButtonType.Normal)
              .backgroundColor('transparent')
              .width('45%')
              .height(50)
              .onClick(() => {
                this.showAIConfig = false;
              })

              Button() {
                Text('保存配置')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .type(ButtonType.Capsule)
              .backgroundColor('#4CAF50')
              .width('45%')
              .height(50)
              .onClick(() => {
                this.saveAIConfig();
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('90%')
          .padding(20)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)
          .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.3)' })
          
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.showAIConfig = false;
        })
      }
    }
    .width('100%')
    .height('100%')
  }
} 