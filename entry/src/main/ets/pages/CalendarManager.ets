// CalendarManager.ets - 日历账户管理页面
// 导入页面路由模块
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { calendarManager } from '@kit.CalendarKit';
import { promptAction } from '@kit.ArkUI';
import { calendarMgr, mContext } from '../entryability/EntryAbility';

@Entry
@Component
struct CalendarManager {
  @State message: string = '📅 日历账户管理'
  @State calendar: calendarManager.Calendar | undefined = undefined
  @State calendarMgr: calendarManager.CalendarManager | undefined = undefined
  @State isCalendarAccountCreated: boolean = false

  // 页面显示时的生命周期回调
  aboutToAppear() {
    this.checkCalendarAccountStatus();
  }

  // 检查日历账户状态
  async checkCalendarAccountStatus() {
    try {
      // 先初始化日历管理器
      if (!this.calendarMgr) {
        await this.initCalendarManager();
      }
      
      if (!this.calendarMgr) {
        return;
      }

      // 检查日历账户是否存在
      const calendarAccount: calendarManager.CalendarAccount = {
        name: 'AICalendar',
        type: calendarManager.CalendarType.LOCAL,
        displayName: 'AI日历'
      };

      try {
        this.calendar = await this.calendarMgr.getCalendar(calendarAccount);
        this.isCalendarAccountCreated = true;
        console.info('Calendar account exists');
      } catch (getError) {
        this.isCalendarAccountCreated = false;
        console.info('Calendar account does not exist');
      }
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to check calendar account status. Code: ${code}, message: ${message}`);
    }
  }

  // 初始化日历管理器
  async initCalendarManager() {
    try {
      if (calendarMgr) {
        this.calendarMgr = calendarMgr;
        console.info('Calendar manager initialized from global');
      } else {
        console.error('Global calendar manager is not available');
        promptAction.showToast({
          message: '日历管理器未初始化，请重启应用',
          duration: 2000
        });
      }
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to initialize calendar manager. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '初始化日历管理器失败: ' + message,
        duration: 2000
      });
    }
  }

  // 初始化日历账户
  async initCalendarAccount() {
    try {
      if (!this.calendarMgr) {
        await this.initCalendarManager();
      }
      
      if (!this.calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化',
          duration: 2000
        });
        return;
      }
      
      // 创建日历账户
      const calendarAccount: calendarManager.CalendarAccount = {
        name: 'AICalendar',
        type: calendarManager.CalendarType.LOCAL,
        displayName: 'AI日历'
      };
      
      try {
        // 先尝试获取，如果不存在则创建
        this.calendar = await this.calendarMgr.getCalendar(calendarAccount);
        promptAction.showToast({
          message: '日历账户已存在',
          duration: 2000
        });
        this.isCalendarAccountCreated = true;
      } catch (getError) {
        // 账户不存在，创建新账户
        this.calendar = await this.calendarMgr.createCalendar(calendarAccount);
        
        // 设置日历配置
        const config: calendarManager.CalendarConfig = {
          enableReminder: true,
          color: '#4CAF50'
        };
        await this.calendar.setConfig(config);
        
        promptAction.showToast({
          message: '日历账户创建成功',
          duration: 2000
        });
        this.isCalendarAccountCreated = true;
        console.info('Calendar account created successfully');
      }
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to initialize calendar account. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '初始化日历账户失败: ' + message,
        duration: 2000
      });
    }
  }

  // 删除日历账户
  async deleteCalendarAccount() {
    try {
      if (!this.calendarMgr) {
        promptAction.showToast({
          message: '日历管理器未初始化',
          duration: 2000
        });
        return;
      }
      
      if (!this.calendar) {
        promptAction.showToast({
          message: '没有可删除的日历账户',
          duration: 2000
        });
        return;
      }
      
      // 删除日历账户
      await this.calendarMgr.deleteCalendar(this.calendar);
      
      this.calendar = undefined;
      this.isCalendarAccountCreated = false;
      
      promptAction.showToast({
        message: '日历账户删除成功',
        duration: 2000
      });
      
      console.info('Calendar account deleted successfully');
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      console.error(`Failed to delete calendar account. Code: ${code}, message: ${message}`);
      promptAction.showToast({
        message: '删除日历账户失败: ' + message,
        duration: 2000
      });
    }
  }

  build() {
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
      .margin({ bottom: 30 })
      
      // 状态显示
      Column() {
        Text('📊 账户状态')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })
        
        Row() {
          Text('日历账户状态：')
            .fontSize(16)
          
          Text(this.isCalendarAccountCreated ? '✅ 已创建' : '❌ 未创建')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isCalendarAccountCreated ? '#4CAF50' : '#F44336')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ bottom: 12 })
        
        if (this.isCalendarAccountCreated && this.calendar) {
          Column() {
            Text('账户信息：')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })
            
            Text(`• 账户名称: AICalendar`)
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 4 })
            
            Text(`• 显示名称: AI日历`)
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 4 })
            
            Text(`• 账户类型: 本地账户`)
              .fontSize(14)
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(8)
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(12)
      .margin({ bottom: 30 })
      
      // 操作按钮
      Column() {
        Text('🛠️ 账户操作')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })
        
        if (!this.isCalendarAccountCreated) {
          Button() {
            Text('🚀 初始化日历账户')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#4CAF50')
          .width('100%')
          .height(55)
          .onClick(() => {
            this.initCalendarAccount();
          })
          .margin({ bottom: 16 })
        } else {
          Button() {
            Text('🔄 重新检查状态')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#2196F3')
          .width('100%')
          .height(50)
          .onClick(() => {
            this.checkCalendarAccountStatus();
          })
          .margin({ bottom: 16 })
          
          Button() {
            Text('🗑️ 删除日历账户')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .backgroundColor('#F44336')
          .width('100%')
          .height(50)
          .onClick(() => {
            this.deleteCalendarAccount();
          })
        }
      }
      .width('100%')
      .padding(20)
      
      Blank()
      
      // 说明文字
      Column() {
        Text('💡 使用说明')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 12 })
        
        Text('• 日历账户是存储日程的基础，需要先创建账户才能添加日程')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ bottom: 8 })
        
        Text('• 删除账户将同时删除该账户下的所有日程，请谨慎操作')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ bottom: 8 })
        
        Text('• 如果遇到问题，可以尝试重新检查状态或重启应用')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')
      .padding(20)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }
} 