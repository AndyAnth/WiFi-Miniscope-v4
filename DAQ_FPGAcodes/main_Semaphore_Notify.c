/* SPI Slave example, sender (uses SPI master driver)

 This example code is in the Public Domain (or CC0 licensed, at your option.)

 Unless required by applicable law or agreed to in writing, this
 software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 CONDITIONS OF ANY KIND, either express or implied.
 */
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "esp_log.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "freertos/queue.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/queue.h"
#include "lwip/err.h"
#include "lwip/sys.h"
#include "lwip/netif.h"
#include "lwip/sockets.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"

//SPI 引脚定义      //这里改用IOMUX管脚
#define GPIO_HANDSHAKE 2
#define GPIO_OUTPUT 11

//The semaphore indicating the slave is ready to receive stuff.
static QueueHandle_t rdySem;

void FPGA_syn(){

	xSemaphoreGive(rdySem);
}

/*
 This ISR is called when the handshake line goes high.
 */
static void IRAM_ATTR gpio_handshake_isr_handler(void *arg) {
	//Sometimes due to interference or ringing or something, we get two irqs after eachother. This is solved by
	//looking at the time between interrupts and refusing any interrupt too close to another one.
	static uint32_t lasthandshaketime_us;
	uint32_t currtime_us = esp_timer_get_time();
	uint32_t diff = currtime_us - lasthandshaketime_us;
	if (diff < 1) {
		return; //ignore everything <1us after an earlier irq
	}
	lasthandshaketime_us = currtime_us;

	//Give the semaphore.
	BaseType_t mustYield = false;
	xSemaphoreGiveFromISR(rdySem, &mustYield);  //要注意，这个中断处理程序触发的前提就是检测到handshake信号的上升沿
	if (mustYield) {
		portYIELD_FROM_ISR();
	}
}

static void spi_receiver(void *pvParameters) {
	esp_err_t ret;

    //GPIO config for the handshake line.
	gpio_config_t io_conf_handshake = { 
        .intr_type = GPIO_INTR_POSEDGE,     //这里是检测到handshake信号的下降沿就进入中断置起信号量
        //这里可以设置两包之间的间隔为100us，并且需要检测进入中断和置起信号量以及SPI相应需要多长时间，在FPGA里留出这个时间裕量
        .mode = GPIO_MODE_INPUT, 
        .pull_down_en = 1,        //这里不太清楚应该是上拉还是下拉
        .pin_bit_mask = (1 << GPIO_HANDSHAKE) 
    };

	//Create the semaphore.
	rdySem = xSemaphoreCreateBinary();

	//Set up handshake line interrupt.
	gpio_config(&io_conf_handshake);
	gpio_install_isr_service(0);
	gpio_set_intr_type(GPIO_HANDSHAKE, GPIO_INTR_POSEDGE);
	gpio_isr_handler_add(GPIO_HANDSHAKE, gpio_handshake_isr_handler, NULL);

	//ESP准备就绪，通知FPGA并等待其回应
	FPGA_syn();

	while (1) {
		xSemaphoreTake(rdySem, portMAX_DELAY); //Wait until slave is ready
        xTaskNotify(gpio_set_task,1,eSetValueWithOverwrite); //覆盖写入当前SPI传入的值
	}

}

static void gpio_set_task(void *pvParameters) {
    static int pin_level;
    while(1){
        xTaskNotifyWait(0,0,&pin_level,portMAX_DELAY); //阻塞接收Notify传来的数据
        gpio_set_level(GPIO_OUTPUT, pin_level);
    }
}

//Main application
void app_main(void) {
	/* 创建Queue */
	//Queue = xQueueCreate((UBaseType_t ) QUEUE_LEN, (UBaseType_t ) QUEUE_SIZE);

    //GPIO config for the output line.
	gpio_config_t io_conf_output = { 
        .intr_type = GPIO_INTR_DISABLE,     //这里是检测到handshake信号的下降沿就进入中断置起信号量
        //这里可以设置两包之间的间隔为100us，并且需要检测进入中断和置起信号量以及SPI相应需要多长时间，在FPGA里留出这个时间裕量
        .mode = GPIO_MODE_OUTPUT, 
        .pull_down_en = 1,        //这里不太清楚应该是上拉还是下拉
        .pull_up_en = 0,
        .pin_bit_mask = (1 << GPIO_OUTPUT) 
    };

    //Set up output line interrupt.
	gpio_config(&io_conf_output);

	xTaskCreatePinnedToCore(spi_receiver, "spi_receiver", 8192, NULL, 5, NULL,0);
	xTaskCreatePinnedToCore(gpio_set_task, "gpio_set_task", 8192, NULL, 2, NULL,1);
}
