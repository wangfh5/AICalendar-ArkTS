// CalendarManager.ets - 日历账户管理页面
// 导入页面路由模块
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { calendarManager } from '@kit.CalendarKit';
import { promptAction } from '@kit.ArkUI';
import { calendarMgr, mContext, AIConfig } from '../entryability/EntryAbility';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

// 默认账户配置类
class DefaultCalendarConfig {
  private static readonly PREF_NAME: string = 'default_calendar_config';
  private static readonly DEFAULT_CALENDAR_KEY: string = 'default_calendar_name';

  static async saveDefaultCalendar(context: common.UIAbilityContext, calendarName: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, DefaultCalendarConfig.PREF_NAME);
      await pref.put(DefaultCalendarConfig.DEFAULT_CALENDAR_KEY, calendarName);
      await pref.flush();
    } catch (error) {
      console.error('保存默认日历配置失败:', error);
    }
  }

  static async getDefaultCalendar(context: common.UIAbilityContext): Promise<string> {
    try {
      const pref = await preferences.getPreferences(context, DefaultCalendarConfig.PREF_NAME);
      return await pref.get(DefaultCalendarConfig.DEFAULT_CALENDAR_KEY, '') as string;
    } catch (error) {
      console.error('获取默认日历配置失败:', error);
      return '';
    }
  }
}

@Entry
@Component
struct CalendarManager {
  @State message: string = '📅 日历账户管理'
  @State allCalendars: calendarManager.Calendar[] = []
  @State selectedCalendarName: string = ''
  @State defaultCalendarName: string = ''
  @State isLoading: boolean = false
  @State showCreateDialog: boolean = false
  
  // 新建账户相关状态
  @State newCalendarName: string = ''
  @State newCalendarDisplayName: string = ''
  @State newCalendarColor: string = '#4CAF50'
  @State enableReminder: boolean = true

  // 页面显示时的生命周期回调
  async aboutToAppear() {
    await this.loadDefaultCalendar();
    await this.loadAllCalendars();
  }

  // 加载默认日历配置
  async loadDefaultCalendar() {
    if (mContext) {
      this.defaultCalendarName = await DefaultCalendarConfig.getDefaultCalendar(mContext);
      this.selectedCalendarName = this.defaultCalendarName;
    }
  }

  // 获取所有日历账户
  async loadAllCalendars() {
    try {
      this.isLoading = true;
      
      if (!calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化，请重启应用',
          duration: 2000
        });
        return;
      }

      // 获取所有日历账户
      this.allCalendars = await calendarMgr.getAllCalendars();
      
      console.info(`获取到 ${this.allCalendars.length} 个日历账户`);
      
      // 如果没有设置默认账户，且有可用账户，选择第一个
      if (!this.selectedCalendarName && this.allCalendars.length > 0) {
        const firstCalendar = this.allCalendars[0];
        const account = firstCalendar.getAccount();
        this.selectedCalendarName = account.name;
      }
      
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`获取日历账户失败. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '获取日历账户失败: ' + message,
        duration: 2000
      });
    } finally {
      this.isLoading = false;
    }
  }

  // 设置默认日历账户
  async setDefaultCalendar(calendarName: string) {
    try {
      if (mContext) {
        await DefaultCalendarConfig.saveDefaultCalendar(mContext, calendarName);
        this.defaultCalendarName = calendarName;
        this.selectedCalendarName = calendarName;
        
        promptAction.showToast({
          message: `已设置 "${calendarName}" 为默认日历`,
          duration: 2000
        });
      }
    } catch (error) {
      console.error('设置默认日历失败:', error);
      promptAction.showToast({
        message: '设置默认日历失败',
        duration: 2000
      });
    }
  }

  // 创建新的日历账户
  async createNewCalendar() {
    try {
      if (!calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化',
          duration: 2000
        });
        return;
      }

      if (!this.newCalendarName.trim()) {
        promptAction.showToast({
          message: '请输入日历账户名称',
          duration: 2000
        });
        return;
      }

      // 检查账户名是否已存在
      const existingCalendar = this.allCalendars.find(cal => {
        const account = cal.getAccount();
        return account.name === this.newCalendarName.trim();
      });

      if (existingCalendar) {
        promptAction.showToast({
          message: '该账户名已存在，请使用其他名称',
          duration: 2000
        });
        return;
      }

      this.isLoading = true;

      // 创建日历账户
      const calendarAccount: calendarManager.CalendarAccount = {
        name: this.newCalendarName.trim(),
        type: calendarManager.CalendarType.LOCAL,
        displayName: this.newCalendarDisplayName.trim() || this.newCalendarName.trim()
      };

      const newCalendar = await calendarMgr.createCalendar(calendarAccount);

      // 设置日历配置
      const config: calendarManager.CalendarConfig = {
        enableReminder: this.enableReminder,
        color: this.newCalendarColor
      };
      await newCalendar.setConfig(config);

      promptAction.showToast({
        message: '日历账户创建成功',
        duration: 2000
      });

      // 重新加载账户列表
      await this.loadAllCalendars();
      
      // 关闭创建对话框并清空表单
      this.showCreateDialog = false;
      this.clearCreateForm();

    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`创建日历账户失败. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '创建日历账户失败: ' + message,
        duration: 2000
      });
    } finally {
      this.isLoading = false;
    }
  }

  // 删除日历账户
  async deleteCalendar(calendar: calendarManager.Calendar) {
    try {
      if (!calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化',
          duration: 2000
        });
        return;
      }

      const account = calendar.getAccount();
      
      // 确认删除
      // 注意：这里应该使用系统对话框，但为了简化，我们使用toast提示
      await calendarMgr.deleteCalendar(calendar);
      
      promptAction.showToast({
        message: `日历账户 "${account.displayName}" 删除成功`,
        duration: 2000
      });

      // 如果删除的是默认账户，清空默认设置
      if (this.defaultCalendarName === account.name) {
        this.defaultCalendarName = '';
        this.selectedCalendarName = '';
        if (mContext) {
          await DefaultCalendarConfig.saveDefaultCalendar(mContext, '');
        }
      }

      // 重新加载账户列表
      await this.loadAllCalendars();

    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`删除日历账户失败. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '删除日历账户失败: ' + message,
        duration: 2000
      });
    }
  }

  // 清空创建表单
  clearCreateForm() {
    this.newCalendarName = '';
    this.newCalendarDisplayName = '';
    this.newCalendarColor = '#4CAF50';
    this.enableReminder = true;
  }

  // 获取日历账户的配置信息
  getCalendarConfigInfo(calendar: calendarManager.Calendar): string {
    try {
      const config = calendar.getConfig();
      return `颜色: ${config.color || '默认'} | 提醒: ${config.enableReminder ? '开启' : '关闭'}`;
    } catch (error) {
      return '配置信息获取失败';
    }
  }

  build() {
    Stack() {
      // 主内容
      Column() {
        // 标题和返回按钮
        Row() {
          Button() {
            Text('  ← 返回  ')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#0D9FFB')
          .height(40)
          .onClick(() => {
            router.back()
          })
          
          Blank()
          
          Text(this.message)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 加载状态
        if (this.isLoading) {
          Row() {
            LoadingProgress()
              .width(30)
              .height(30)
              .color('#4CAF50')
            
            Text('加载中...')
              .fontSize(16)
              .margin({ left: 12 })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 20 })
        }

        // 操作按钮区域
        Row() {
          Button() {
            Text('🔄 刷新列表')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#2196F3')
          .width('45%')
          .height(45)
          .onClick(() => {
            this.loadAllCalendars();
          })

          Button() {
            Text('➕ 新建账户')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#4CAF50')
          .width('45%')
          .height(45)
          .onClick(() => {
            this.showCreateDialog = true;
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 20 })

        // 默认账户显示
        if (this.defaultCalendarName) {
          Column() {
            Text('🎯 当前默认账户')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
            
            Text(`"${this.defaultCalendarName}"`)
              .fontSize(16)
              .fontColor('#4CAF50')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(12)
          .margin({ bottom: 20 })
        }

                // 日历账户列表
        Column() {
          Text(`📋 所有日历账户 (${this.allCalendars.length})`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 16 })

          // 可滚动的账户列表
          Scroll() {
            Column() {
              if (this.allCalendars.length === 0 && !this.isLoading) {
                Text('暂无日历账户，请创建一个新账户')
                  .fontSize(16)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .textAlign(TextAlign.Center)
                  .margin({ top: 40, bottom: 40 })
              } else {
                ForEach(this.allCalendars, (calendar: calendarManager.Calendar, index: number) => {
                  Column() {
                    Text(calendar.getAccount().displayName || calendar.getAccount().name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .margin({ bottom: 8 })
                    
                    Text(`账户名: ${calendar.getAccount().name}`)
                      .fontSize(14)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .margin({ bottom: 4 })
                    
                    Text(this.getCalendarConfigInfo(calendar))
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .margin({ bottom: 12 })
                    
                    Row() {
                      if (this.defaultCalendarName !== calendar.getAccount().name) {
                        Button('设为默认')
                          .fontSize(12)
                          .type(ButtonType.Capsule)
                          .backgroundColor('#FF9800')
                          .height(32)
                          .onClick(() => {
                            this.setDefaultCalendar(calendar.getAccount().name);
                          })
                          .margin({ right: 8 })
                      }
                      
                      Button('删除')
                        .fontSize(12)
                        .type(ButtonType.Capsule)
                        .backgroundColor('#F44336')
                        .height(32)
                        .onClick(() => {
                          this.deleteCalendar(calendar);
                        })
                    }
                    .justifyContent(FlexAlign.End)
                  }
                  .width('100%')
                  .padding(16)
                  .backgroundColor($r('sys.color.ohos_id_color_background'))
                  .borderRadius(8)
                  .margin({ bottom: 12 })
                  .border({
                    width: this.selectedCalendarName === calendar.getAccount().name ? 2 : 1,
                    color: this.selectedCalendarName === calendar.getAccount().name ? '#4CAF50' : $r('sys.color.ohos_id_color_list_separator')
                  })
                  .onClick(() => {
                    this.selectedCalendarName = calendar.getAccount().name;
                  })
                })
              }
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .layoutWeight(1)

        // 使用说明（固定在底部）
        Column() {
          Text('💡 使用说明')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 8 })
          
          Text('• 选择账户作为默认，AI日程将添加到该账户 • 可创建多个账户分类管理 • 删除账户会删除所有日程')
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(8)
        .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .padding(20)

      // 创建账户对话框
      if (this.showCreateDialog) {
        Column() {
          Blank()
          
          Column() {
            Text('➕ 创建新日历账户')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })
            
            // 账户名称
            Column() {
              Text('账户名称 *')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              TextInput({ 
                placeholder: '请输入账户名称（英文）',
                text: this.newCalendarName
              })
                .onChange((value: string) => {
                  this.newCalendarName = value;
                })
                .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 显示名称
            Column() {
              Text('显示名称')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              TextInput({ 
                placeholder: '请输入显示名称（可中文）',
                text: this.newCalendarDisplayName
              })
                .onChange((value: string) => {
                  this.newCalendarDisplayName = value;
                })
                .width('100%')
            }
            .width('100%')
            .margin({ bottom: 16 })
            
            // 账户颜色
            Column() {
              Text('账户颜色')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              
              Row() {
                ForEach(['#4CAF50', '#2196F3', '#FF9800', '#F44336', '#9C27B0', '#607D8B'], (color: string) => {
                  Stack() {
                    // 颜色圆圈
                    Circle()
                      .width(40)
                      .height(40)
                      .fill(color)
                    
                    // 选中标记
                    if (this.newCalendarColor === color) {
                      Text('✓')
                        .fontSize(18)
                        .fontColor('#FFFFFF')
                        .fontWeight(FontWeight.Bold)
                    }
                  }
                  .width(40)
                  .height(40)
                  .onClick(() => {
                    this.newCalendarColor = color;
                  })
                  .margin({ right: 12 })
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })
            
            // 提醒设置
            Row() {
              Checkbox()
                .select(this.enableReminder)
                .onChange((value: boolean) => {
                  this.enableReminder = value;
                })
              
              Text('启用日程提醒')
                .fontSize(16)
                .margin({ left: 8 })
            }
            .alignItems(VerticalAlign.Center)
            .alignSelf(ItemAlign.Start)
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
                this.showCreateDialog = false;
                this.clearCreateForm();
              })

              Button() {
                Text('创建账户')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .type(ButtonType.Capsule)
              .backgroundColor('#4CAF50')
              .width('45%')
              .height(50)
              .onClick(() => {
                this.createNewCalendar();
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
          this.showCreateDialog = false;
        })
      }
    }
    .width('100%')
    .height('100%')
  }
} 