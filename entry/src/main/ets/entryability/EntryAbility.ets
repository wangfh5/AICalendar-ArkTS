// For Calendar
import { abilityAccessCtrl, AbilityConstant, common, PermissionRequestResult, Permissions, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { calendarManager } from '@kit.CalendarKit';
import { window } from '@kit.ArkUI';
import http from '@ohos.net.http';
import { preferences } from '@kit.ArkData';

// EntryAbility.ets
export let calendarMgr: calendarManager.CalendarManager | null = null;
export let mContext: common.UIAbilityContext | null = null;

// AI解析相关接口和类
export interface ParsedEventData {
  summary: string;
  startTime: string;
  endTime: string;
  location?: string;
  description?: string;
  reminderMinutes: number;
  isRecurring: boolean;
  recurrenceFrequency?: string;
  recurrenceCount?: number;
}

// 定义AI请求消息接口
interface AIMessage {
  role: string;
  content: string;
}

// 定义AI请求体接口
interface AIRequestBody {
  model: string;
  messages: AIMessage[];
  temperature: number;
}

// 定义AI响应接口
interface AIResponse {
  choices: AIChoice[];
}

interface AIChoice {
  message: AIMessage;
}

// 定义解析后的事件数据接口
interface RawEventData {
  summary?: string;
  startTime?: string;
  endTime?: string;
  location?: string;
  description?: string;
  reminderMinutes?: number;
  isRecurring?: boolean;
  recurrenceFrequency?: string;
  recurrenceCount?: number;
}

export class AITextParser {
  private apiKey: string;
  private baseUrl: string;
  private model: string;

  constructor(apiKey: string, baseUrl: string = 'https://api.deepseek.com', model: string = 'deepseek-chat') {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.model = model;
  }

  async parseText(text: string): Promise<ParsedEventData> {
    const systemPrompt = this.getSystemPrompt();
    
    const messages: AIMessage[] = [
      { role: "system", content: systemPrompt },
      { role: "user", content: text }
    ];

    const requestBody: AIRequestBody = {
      model: this.model,
      messages: messages,
      temperature: 0.1
    };

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`
    };

    try {
      const response = await this.httpPost(
        `${this.baseUrl}/chat/completions`,
        headers,
        JSON.stringify(requestBody)
      );

      const jsonResponse: AIResponse = JSON.parse(response) as AIResponse;
      const content = jsonResponse.choices[0].message.content;
      
      // 添加调试日志
      console.info('AI返回的原始内容:', content);
      
      // 尝试提取JSON内容
      const cleanedContent = this.extractJSON(content);
      console.info('提取的JSON内容:', cleanedContent);
      
      const eventData: RawEventData = JSON.parse(cleanedContent) as RawEventData;

      return this.convertToEventData(eventData);
    } catch (error) {
      const err = error as Error;
      console.error('AI解析详细错误:', err);
      throw new Error(`AI解析失败: ${err.message}`);
    }
  }

  private async httpPost(url: string, headers: Record<string, string>, body: string): Promise<string> {
    const httpRequest = http.createHttp();
    
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        readTimeout: 30000,
        connectTimeout: 10000
      });
      
      if (response.responseCode === 200) {
        return response.result as string;
      } else {
        throw new Error(`HTTP Error: ${response.responseCode}`);
      }
    } finally {
      httpRequest.destroy();
    }
  }

  private getSystemPrompt(): string {
    const currentDate = new Date().toISOString().split('T')[0];
    return `You are a calendar event parsing assistant. Your task is to extract event information from natural language descriptions.

Please extract the following information in JSON format:
{
    "summary": "Event title",
    "startTime": "YYYY-MM-DDTHH:mm:ss",
    "endTime": "YYYY-MM-DDTHH:mm:ss",
    "location": "Location",
    "description": "Detailed event information, excluding time/location/basic attendee info that are covered by other fields",
    "reminderMinutes": reminder time in minutes
    "isRecurring": true or false
    "recurrenceFrequency": "daily/weekly/monthly/yearly"
    "recurrenceCount": recurrence count
}

今天的日期是 ${currentDate}。

2025年节假日调休安排：
- 元旦：2024-12-30 至 2025-01-01，共3天
- 春节：2025-01-28 至 2025-02-04，共8天
- 清明节：2025-04-05 至 2025-04-07，共3天
- 劳动节：2025-05-01 至 2025-05-05，共5天
- 端午节：2025-05-31 至 2025-06-02，共3天
- 中秋节：2025-10-06，共1天（与国庆节连休）
- 国庆节：2025-10-01 至 2025-10-08，共8天

Rules:
1. Language matching (IMPORTANT):
   - For Chinese input (contains any Chinese characters), MUST output summary and description in Chinese
   - For English input (no Chinese characters), output summary and description in English
   - Examples for Chinese input:
     - Input: "明天下午3点在星巴克见面" -> summary: "星巴克见面"
     - Input: "下周一开产品评审会" -> summary: "产品评审会"
   - Examples for English input:
     - Input: "meeting tomorrow 3pm" -> summary: "Meeting"
     - Input: "product review next Monday" -> summary: "Product Review"

2. Time parsing rules:
   - "today" refers to $currentDate
   - "tomorrow" means the next day
   - "next Monday" means the next occurring Monday
   - For dates like "Jan 25th", assume it's in the current year unless specified
   - If only time is given without date, assume today ($currentDate)
   - Parse all times to 24-hour format (e.g., "2pm" -> "14:00")
   - For morning/afternoon without specific time: morning = 9:00, afternoon = 14:00

3. Duration rules:
   - If no end time is specified, assume the event lasts for 1 hour
   - For "lunch" or "dinner" without specified duration, assume 1.5 hours
   - For "meeting" without specified duration, assume 1 hour

4. Location handling:
   - If no location is specified, return null
   - Keep the exact location name as provided
   - For online meetings:
     * Use "Online" (English) or "线上" (Chinese) as location
     * DO NOT remove meeting details from description
     * Meeting details (ID, password, etc.) MUST stay in description

5. Recurrence rules:
   - If "daily", "weekly", "monthly", or "yearly" is mentioned, set isRecurring to true
   - "daily" = daily, "weekly" = weekly, "monthly" = monthly, "yearly" = yearly

6. Reminder rules:
   - Default reminder is 15 minutes before
   - Parse explicit reminder times (e.g., "remind me 1 hour before" -> 60)
   - For important meetings/presentations, set default reminder to 30 minutes

7. Title rules:
   - Make the summary concise but informative
   - Include the meeting type (e.g., "Team Meeting"/"团队会议", "Client Meeting"/"客户会议")
   - For academic talks, use the format: "[Series Name] [Talk Title]"

8. Description rules:
   - IMPORTANT: Keep the text AS IS, only remove duplicated basic event info
   - DO NOT try to make the description concise
   - CRITICAL: Meeting connection details MUST be preserved:
     * Meeting platform (Zoom, Teams, Tencent Meeting, 腾讯会议等)
     * Meeting ID/room number
     * Meeting passwords/passcode
     * Meeting links
     * Any other connection instructions
   - DO NOT remove or modify any of these:
     * References and citations
     * Bibliography/reference list
     * Technical details
     * Abstract content
     * Biography
   - Only remove information that is exactly duplicated in other fields:
     * Basic time/date info (but keep timezone information)
     * Basic location info (but keep online meeting details)
     * Basic attendee list
   - Keep the original text structure and formatting
     * Add line breaks between sections
     * For Bibliography/reference list, each item should be on a new line

9. Only return JSON, no other text`;
  }

  private extractJSON(text: string): string {
    // 尝试多种方式提取JSON内容
    
    // 1. 如果文本本身就是JSON，直接返回
    try {
      JSON.parse(text);
      return text;
    } catch {
      // 继续尝试其他方法
    }
    
    // 2. 查找JSON代码块（```json ... ```）
    const jsonBlockMatch = text.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonBlockMatch) {
      return jsonBlockMatch[1].trim();
    }
    
    // 3. 查找普通代码块（``` ... ```）
    const codeBlockMatch = text.match(/```\s*([\s\S]*?)\s*```/);
    if (codeBlockMatch) {
      return codeBlockMatch[1].trim();
    }
    
    // 4. 查找大括号包围的JSON对象
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return jsonMatch[0];
    }
    
    // 5. 如果都找不到，返回原文本
    console.warn('无法从AI返回内容中提取JSON，返回原文本');
    return text;
  }

  private convertToEventData(data: RawEventData): ParsedEventData {
    const result: ParsedEventData = {
      summary: data.summary || '',
      startTime: data.startTime || '',
      endTime: data.endTime || '',
      location: data.location || undefined,
      description: data.description || undefined,
      reminderMinutes: data.reminderMinutes || 15,
      isRecurring: data.isRecurring || false,
      recurrenceFrequency: data.recurrenceFrequency || undefined,
      recurrenceCount: data.recurrenceCount || 1
    };
    return result;
  }
}

// 定义配置返回接口
interface AIConfigResult {
  apiKey: string;
  baseUrl: string;
  model: string;
}

export class AIConfig {
  private static readonly PREF_NAME: string = 'ai_config';
  private static readonly API_KEY: string = 'api_key';
  private static readonly BASE_URL: string = 'base_url';
  private static readonly MODEL: string = 'model';

  static async saveConfig(context: common.UIAbilityContext, apiKey: string, baseUrl: string, model: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, AIConfig.PREF_NAME);
      await pref.put(AIConfig.API_KEY, apiKey);
      await pref.put(AIConfig.BASE_URL, baseUrl);
      await pref.put(AIConfig.MODEL, model);
      await pref.flush();
    } catch (error) {
      console.error('保存AI配置失败:', error);
    }
  }

  static async getConfig(context: common.UIAbilityContext): Promise<AIConfigResult> {
    try {
      const pref = await preferences.getPreferences(context, AIConfig.PREF_NAME);
      const apiKey = await pref.get(AIConfig.API_KEY, '') as string;
      const baseUrl = await pref.get(AIConfig.BASE_URL, 'https://api.deepseek.com') as string;
      const model = await pref.get(AIConfig.MODEL, 'deepseek-chat') as string;
      
      const result: AIConfigResult = { apiKey, baseUrl, model };
      return result;
    } catch (error) {
      console.error('获取AI配置失败:', error);
      const defaultResult: AIConfigResult = { 
        apiKey: '', 
        baseUrl: 'https://api.deepseek.com', 
        model: 'deepseek-chat' 
      };
      return defaultResult;
    }
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.info("Ability onCreate");
  }


  onDestroy(): void {
    console.info("Ability onDestroy");
  }


  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    console.info("Ability onWindowStageCreate");
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error(`Failed to load the content. Code: ${err.code}, message: ${err.message}`);
        return;
      }
      console.info(`Succeeded in loading the content. Data: ${JSON.stringify(data)}`);
    });
    mContext = this.context;
    const permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];
    let atManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(mContext, permissions).then((result: PermissionRequestResult) => {
      console.info(`get Permission success, result: ${JSON.stringify(result)}`);
      calendarMgr = calendarManager.getCalendarManager(mContext);
    }).catch((error: BusinessError) => {
      console.error(`get Permission error, error. Code: ${error.code}, message: ${error.message}`);
    })
  }


  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    console.info("Ability onWindowStageDestroy");
  }


  onForeground(): void {
    // Ability has brought to foreground
    console.info("Ability onForeground");
  }


  onBackground(): void {
    // Ability has back to background
    console.info("Ability onBackground");
  }
}