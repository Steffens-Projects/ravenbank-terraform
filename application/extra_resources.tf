# Create Route 53 record that points to ALB
resource "aws_route53_record" "route53_record" {
    zone_id = data.aws_route53_zone.hosted_zone_data.zone_id
    name = "ravenbank.${var.hosted_zone}"
    type = "A"
    alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = false
  }
  depends_on = [aws_lb.load_balancer]
}